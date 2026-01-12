#!/bin/bash

#########################################################################################
# Script Name:  checkAdminUsers.sh
# Purpose:      List all users in admin group
# Date:         January 2026
#
# Jamf Parameters:
#   None
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
OUTPUT_FORMAT="detailed"  # Options: simple, detailed, jamf

#########################################################################################
# FUNCTIONS
#########################################################################################

logMessage() {
    local message="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${timestamp}: ${message}" | tee -a "${LOG_FILE}"
}

getAdminGroupMembers() {
    # Get members of the admin group using dscl
    dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/GroupMembership: //' | tr ' ' '\n'
}

getNestedAdminMembers() {
    # Get nested group members (groups that are members of admin)
    local nestedGroups
    nestedGroups=$(dscl . -read /Groups/admin NestedGroups 2>/dev/null | sed 's/NestedGroups: //')

    if [[ -n "${nestedGroups}" ]]; then
        for groupGUID in ${nestedGroups}; do
            # Convert GUID to group name
            local groupName
            groupName=$(dscl . -search /Groups GeneratedUID "${groupGUID}" 2>/dev/null | head -1 | awk '{print $1}')
            if [[ -n "${groupName}" ]]; then
                echo "Group: ${groupName}"
                # Get members of nested group
                dscl . -read "/Groups/${groupName}" GroupMembership 2>/dev/null | sed 's/GroupMembership: //' | tr ' ' '\n' | sed 's/^/  /'
            fi
        done
    fi
}

getUserDetails() {
    local username="$1"
    local userUID
    local realName
    local homeDir
    local isLocal

    userUID=$(dscl . -read "/Users/${username}" UniqueID 2>/dev/null | awk '{print $2}')
    realName=$(dscl . -read "/Users/${username}" RealName 2>/dev/null | sed -n 's/^RealName: //p')
    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

    # Check if account is local or mobile
    if dscl . -read "/Users/${username}" OriginalAuthenticationAuthority &>/dev/null; then
        isLocal="Mobile AD Account"
    else
        isLocal="Local Account"
    fi

    echo "  Username: ${username}"
    echo "  Full Name: ${realName:-N/A}"
    echo "  UID: ${userUID:-N/A}"
    echo "  Home: ${homeDir:-N/A}"
    echo "  Type: ${isLocal}"
    echo ""
}

isSystemAccount() {
    local username="$1"
    local userUID

    userUID=$(dscl . -read "/Users/${username}" UniqueID 2>/dev/null | awk '{print $2}')

    # System accounts typically have UID < 500
    if [[ -n "${userUID}" ]] && [[ "${userUID}" -lt 500 ]]; then
        return 0
    fi

    # Also check for underscore prefix (service accounts)
    if [[ "${username}" == _* ]]; then
        return 0
    fi

    return 1
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting checkAdminUsers.sh =========="

echo "========================================"
echo "Admin Group Members Report"
echo "Generated: $(date)"
echo "========================================"
echo ""

# Get all admin members
adminMembers=$(getAdminGroupMembers)

if [[ -z "${adminMembers}" ]]; then
    logMessage "No members found in admin group"
    echo "No members found in admin group"
    exit 0
fi

# Count and categorize
totalAdmins=0
localAdmins=0
systemAdmins=0

echo "--- User Admin Accounts ---"
echo ""

for member in ${adminMembers}; do
    ((totalAdmins++))

    if isSystemAccount "${member}"; then
        ((systemAdmins++))
        continue  # Skip system accounts in main listing
    fi

    ((localAdmins++))

    # Check if user record exists
    if dscl . -read "/Users/${member}" &>/dev/null; then
        getUserDetails "${member}"
    else
        echo "  Username: ${member}"
        echo "  Status: User record not found (possibly deleted)"
        echo ""
    fi
done

echo ""
echo "--- System Admin Accounts ---"
echo ""

for member in ${adminMembers}; do
    if isSystemAccount "${member}"; then
        echo "  ${member}"
    fi
done

echo ""
echo "--- Nested Groups ---"
echo ""
nestedOutput=$(getNestedAdminMembers)
if [[ -n "${nestedOutput}" ]]; then
    echo "${nestedOutput}"
else
    echo "  No nested groups found"
fi

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Total Admin Members: ${totalAdmins}"
echo "User Accounts: ${localAdmins}"
echo "System Accounts: ${systemAdmins}"
echo ""

# Output for Jamf Extension Attribute (if needed)
logMessage "Found ${totalAdmins} total admin members (${localAdmins} user accounts, ${systemAdmins} system accounts)"

# Create comma-separated list of non-system admins for Jamf EA
jamfOutput=""
for member in ${adminMembers}; do
    if ! isSystemAccount "${member}"; then
        if [[ -n "${jamfOutput}" ]]; then
            jamfOutput="${jamfOutput}, ${member}"
        else
            jamfOutput="${member}"
        fi
    fi
done

echo "<result>${jamfOutput}</result>"

logMessage "Script completed successfully"
exit 0
