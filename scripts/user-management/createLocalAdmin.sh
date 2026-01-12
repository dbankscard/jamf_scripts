#!/bin/bash

#########################################################################################
# Script Name:  createLocalAdmin.sh
# Purpose:      Create local admin account with random password (LAPS-style)
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = username (required)
#   $5 = fullname (required)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
USERNAME="$4"
FULLNAME="$5"

# Constants
PASSWORD_LENGTH=16
LOG_FILE="/var/log/jamf_user_management.log"

#########################################################################################
# FUNCTIONS
#########################################################################################

logMessage() {
    local message="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${timestamp}: ${message}" | tee -a "${LOG_FILE}"
}

generateRandomPassword() {
    # Generate a random password with letters, numbers, and special characters
    local password
    password=$(openssl rand -base64 24 | tr -d '/+=' | head -c "${PASSWORD_LENGTH}")
    echo "${password}"
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
    echo $((lastUID + 1))
}

createAdminAccount() {
    local password
    local uniqueID

    password=$(generateRandomPassword)
    uniqueID=$(getNextUID)

    logMessage "Creating admin account: ${USERNAME} (${FULLNAME})"

    # Create the user account using sysadminctl
    if sysadminctl -addUser "${USERNAME}" -fullName "${FULLNAME}" -password "${password}" -admin 2>&1 | tee -a "${LOG_FILE}"; then
        logMessage "Successfully created admin account: ${USERNAME}"

        # Store the password securely (LAPS-style - could be extended to store in Jamf Extension Attribute)
        # For security, we log that the password was generated but not the actual password
        logMessage "Random password generated for ${USERNAME} - length: ${PASSWORD_LENGTH} characters"

        # Output password to Jamf policy log (visible in policy logs only)
        echo "<result>${password}</result>"

        return 0
    else
        logMessage "ERROR: Failed to create admin account: ${USERNAME}"
        return 1
    fi
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting createLocalAdmin.sh =========="

# Validate parameters
validateParameters

# Check if user already exists
checkUserExists

# Create the admin account
if createAdminAccount; then
    logMessage "Script completed successfully"
    exit 0
else
    logMessage "Script failed"
    exit 1
fi
