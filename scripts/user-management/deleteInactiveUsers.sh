#!/bin/bash

#########################################################################################
# Script Name:  deleteInactiveUsers.sh
# Purpose:      Delete user accounts inactive for X days
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = days threshold (optional, default: 90)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
DAYS_THRESHOLD="${4:-90}"

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
PROTECTED_USERS=("root" "daemon" "nobody" "_www" "_mysql" "_windowserver" "_spotlight" "_mbsetupuser")
MIN_UID=500

#########################################################################################
# FUNCTIONS
#########################################################################################

logMessage() {
    local message="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${timestamp}: ${message}" | tee -a "${LOG_FILE}"
}

validateParameters() {
    if ! [[ "${DAYS_THRESHOLD}" =~ ^[0-9]+$ ]]; then
        logMessage "ERROR: Days threshold must be a positive integer"
        exit 1
    fi

    if [[ "${DAYS_THRESHOLD}" -lt 1 ]]; then
        logMessage "ERROR: Days threshold must be at least 1"
        exit 1
    fi
}

isProtectedUser() {
    local username="$1"

    for protected in "${PROTECTED_USERS[@]}"; do
        if [[ "${username}" == "${protected}" ]]; then
            return 0
        fi
    done

    # Also protect users with UID below MIN_UID
    local userUID
    userUID=$(dscl . -read "/Users/${username}" UniqueID 2>/dev/null | awk '{print $2}')
    if [[ -n "${userUID}" ]] && [[ "${userUID}" -lt "${MIN_UID}" ]]; then
        return 0
    fi

    return 1
}

getLastLoginDate() {
    local username="$1"
    local homeDir
    local lastAccess

    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

    if [[ -d "${homeDir}" ]]; then
        # Get last access time of home directory
        lastAccess=$(stat -f "%m" "${homeDir}" 2>/dev/null)
        echo "${lastAccess}"
    else
        echo "0"
    fi
}

isUserInactive() {
    local username="$1"
    local lastLogin
    local currentTime
    local daysSinceLogin
    local thresholdSeconds

    lastLogin=$(getLastLoginDate "${username}")
    currentTime=$(date +%s)

    if [[ "${lastLogin}" == "0" ]]; then
        # No home directory or can't determine last access
        return 1
    fi

    daysSinceLogin=$(( (currentTime - lastLogin) / 86400 ))

    if [[ "${daysSinceLogin}" -ge "${DAYS_THRESHOLD}" ]]; then
        logMessage "User ${username} last active ${daysSinceLogin} days ago (threshold: ${DAYS_THRESHOLD})"
        return 0
    fi

    return 1
}

deleteUser() {
    local username="$1"
    local homeDir

    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

    logMessage "Deleting user account: ${username}"

    # Delete the user account
    if sysadminctl -deleteUser "${username}" 2>&1 | tee -a "${LOG_FILE}"; then
        logMessage "Successfully deleted user: ${username}"

        # Remove home directory if it still exists
        if [[ -d "${homeDir}" ]]; then
            logMessage "Removing home directory: ${homeDir}"
            rm -rf "${homeDir}"
        fi

        return 0
    else
        logMessage "ERROR: Failed to delete user: ${username}"
        return 1
    fi
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting deleteInactiveUsers.sh =========="
logMessage "Inactive threshold: ${DAYS_THRESHOLD} days"

# Validate parameters
validateParameters

# Get list of all users
deletedCount=0
errorCount=0

while IFS= read -r username; do
    # Skip protected users
    if isProtectedUser "${username}"; then
        continue
    fi

    # Check if user is inactive
    if isUserInactive "${username}"; then
        if deleteUser "${username}"; then
            ((deletedCount++))
        else
            ((errorCount++))
        fi
    fi
done < <(dscl . -list /Users | grep -v "^_")

logMessage "Deleted ${deletedCount} inactive user accounts"

if [[ "${errorCount}" -gt 0 ]]; then
    logMessage "WARNING: ${errorCount} users could not be deleted"
    exit 1
fi

logMessage "Script completed successfully"
exit 0
