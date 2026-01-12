#!/bin/bash

#purpose: Remove admin rights from specified user (Jamf parameter $4 for username)
#date: January 2026

# Constants
SCRIPT_NAME="removeAdminRights"
LOG_TAG="[${SCRIPT_NAME}]"
ADMIN_GROUP="admin"

# Jamf Parameters
# $4 = Username to remove admin rights from
targetUser="${4}"

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

checkRoot() {
    if [[ $(id -u) -ne 0 ]]; then
        logMessage "ERROR: This script must be run as root"
        exit 1
    fi
}

validateUser() {
    local username="$1"

    # Check if username is provided
    if [[ -z "${username}" ]]; then
        logMessage "ERROR: No username provided"
        logMessage "Usage: Provide username via Jamf parameter \$4"
        exit 1
    fi

    # Check if user exists
    if ! /usr/bin/id "${username}" &>/dev/null; then
        logMessage "ERROR: User '${username}' does not exist"
        exit 1
    fi

    return 0
}

isUserAdmin() {
    local username="$1"

    # Check if user is in admin group
    if /usr/bin/dsmemberutil checkmembership -U "${username}" -G "${ADMIN_GROUP}" 2>/dev/null | grep -q "is a member"; then
        return 0
    else
        return 1
    fi
}

getAdminUsers() {
    /usr/bin/dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/GroupMembership: //' || echo ""
}

# Main script
logMessage "Starting admin rights removal process..."

# Check for root privileges
checkRoot

# Validate the target user
validateUser "${targetUser}"

logMessage "Target user: ${targetUser}"

# Check if user is currently an admin
if ! isUserAdmin "${targetUser}"; then
    logMessage "User '${targetUser}' is not currently an admin"
    logMessage "No action required"
    exit 0
fi

logMessage "User '${targetUser}' is currently an admin"

# Get current admin users for logging
currentAdmins=$(getAdminUsers)
logMessage "Current admin users: ${currentAdmins}"

# Count admins before removal
adminCount=$(echo "${currentAdmins}" | wc -w | tr -d ' ')
logMessage "Number of admin users: ${adminCount}"

# Safety check - don't remove if this is the only admin
if [[ ${adminCount} -le 1 ]]; then
    logMessage "ERROR: Cannot remove admin rights - '${targetUser}' is the only admin user"
    logMessage "At least one admin user must remain on the system"
    exit 1
fi

# Remove user from admin group using dseditgroup
logMessage "Removing '${targetUser}' from admin group..."

/usr/sbin/dseditgroup -o edit -d "${targetUser}" -t user "${ADMIN_GROUP}" 2>&1
dseditgroupExitCode=$?

if [[ ${dseditgroupExitCode} -ne 0 ]]; then
    logMessage "WARNING: dseditgroup may have encountered an issue"

    # Alternative method using dscl
    logMessage "Attempting alternative removal method using dscl..."
    /usr/bin/dscl . -delete /Groups/admin GroupMembership "${targetUser}" 2>&1
    dsclExitCode=$?

    if [[ ${dsclExitCode} -ne 0 ]]; then
        logMessage "ERROR: Failed to remove admin rights using both methods"
        exit 1
    fi
fi

# Verify removal
sleep 1  # Brief pause to allow directory services to update

if isUserAdmin "${targetUser}"; then
    logMessage "ERROR: User '${targetUser}' is still an admin after removal attempt"
    exit 1
fi

# Get updated admin users
updatedAdmins=$(getAdminUsers)
logMessage "Updated admin users: ${updatedAdmins}"

logMessage "Successfully removed admin rights from '${targetUser}'"
logMessage "User '${targetUser}' is now a standard user"

exit 0
