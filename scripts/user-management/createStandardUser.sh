#!/bin/bash

#########################################################################################
# Script Name:  createStandardUser.sh
# Purpose:      Create standard (non-admin) user account
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = username (required)
#   $5 = fullname (required)
#   $6 = password (required)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
USERNAME="$4"
FULLNAME="$5"
PASSWORD="$6"

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
MIN_PASSWORD_LENGTH=8
DEFAULT_SHELL="/bin/zsh"

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
    if [[ -z "${USERNAME}" ]]; then
        logMessage "ERROR: Username parameter (\$4) is required"
        exit 1
    fi

    if [[ -z "${FULLNAME}" ]]; then
        logMessage "ERROR: Full name parameter (\$5) is required"
        exit 1
    fi

    if [[ -z "${PASSWORD}" ]]; then
        logMessage "ERROR: Password parameter (\$6) is required"
        exit 1
    fi

    # Validate username format
    if ! [[ "${USERNAME}" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        logMessage "ERROR: Username must start with a letter and contain only lowercase letters, numbers, underscores, or hyphens"
        exit 1
    fi

    # Validate password length
    if [[ ${#PASSWORD} -lt ${MIN_PASSWORD_LENGTH} ]]; then
        logMessage "ERROR: Password must be at least ${MIN_PASSWORD_LENGTH} characters"
        exit 1
    fi
}

checkUserExists() {
    if dscl . -read "/Users/${USERNAME}" &>/dev/null; then
        logMessage "ERROR: User '${USERNAME}' already exists"
        exit 1
    fi
}

getNextUID() {
    # Find the next available UID above 500
    local lastUID
    lastUID=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)

    if [[ "${lastUID}" -lt 500 ]]; then
        echo "501"
    else
        echo $((lastUID + 1))
    fi
}

createUserAccount() {
    local uniqueID
    uniqueID=$(getNextUID)

    logMessage "Creating standard user account: ${USERNAME} (${FULLNAME})"
    logMessage "Assigned UID: ${uniqueID}"

    # Create the user account using sysadminctl (non-admin)
    if sysadminctl -addUser "${USERNAME}" -fullName "${FULLNAME}" -password "${PASSWORD}" -shell "${DEFAULT_SHELL}" 2>&1 | tee -a "${LOG_FILE}"; then
        logMessage "Successfully created standard user account: ${USERNAME}"
        return 0
    else
        logMessage "ERROR: sysadminctl failed, trying manual dscl method"

        # Fallback to manual dscl creation
        if createUserManually "${uniqueID}"; then
            return 0
        else
            return 1
        fi
    fi
}

createUserManually() {
    local uniqueID="$1"
    local homeDir="/Users/${USERNAME}"

    logMessage "Creating user manually with dscl"

    # Create user record
    dscl . -create "/Users/${USERNAME}" || return 1
    dscl . -create "/Users/${USERNAME}" UserShell "${DEFAULT_SHELL}" || return 1
    dscl . -create "/Users/${USERNAME}" RealName "${FULLNAME}" || return 1
    dscl . -create "/Users/${USERNAME}" UniqueID "${uniqueID}" || return 1
    dscl . -create "/Users/${USERNAME}" PrimaryGroupID 20 || return 1  # staff group
    dscl . -create "/Users/${USERNAME}" NFSHomeDirectory "${homeDir}" || return 1

    # Set password
    dscl . -passwd "/Users/${USERNAME}" "${PASSWORD}" || return 1

    # Create home directory
    createhomedir -c -u "${USERNAME}" 2>/dev/null || {
        # Fallback: manually create home directory structure
        mkdir -p "${homeDir}"
        cp -R /System/Library/User\ Template/English.lproj/ "${homeDir}/"
        chown -R "${uniqueID}:20" "${homeDir}"
        chmod 755 "${homeDir}"
    }

    logMessage "Successfully created user manually with dscl"
    return 0
}

verifyUserCreation() {
    if dscl . -read "/Users/${USERNAME}" &>/dev/null; then
        local createdUID
        local createdHome

        createdUID=$(dscl . -read "/Users/${USERNAME}" UniqueID | awk '{print $2}')
        createdHome=$(dscl . -read "/Users/${USERNAME}" NFSHomeDirectory | awk '{print $2}')

        logMessage "Verified user creation:"
        logMessage "  Username: ${USERNAME}"
        logMessage "  Full Name: ${FULLNAME}"
        logMessage "  UID: ${createdUID}"
        logMessage "  Home: ${createdHome}"

        # Verify user is NOT an admin
        if dseditgroup -o checkmember -m "${USERNAME}" admin &>/dev/null; then
            logMessage "WARNING: User is in admin group - removing"
            dseditgroup -o edit -d "${USERNAME}" -t user admin
        fi

        return 0
    else
        logMessage "ERROR: User verification failed"
        return 1
    fi
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting createStandardUser.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if user already exists
checkUserExists

# Create the user account
if createUserAccount; then
    if verifyUserCreation; then
        logMessage "Script completed successfully"
        exit 0
    fi
fi

logMessage "Script failed"
exit 1
