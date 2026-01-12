#!/bin/bash

#########################################################################################
# Script Name:  resetUserPassword.sh
# Purpose:      Reset local user password
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = username (required)
#   $5 = newpassword (required)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
USERNAME="$4"
NEW_PASSWORD="$5"

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
MIN_PASSWORD_LENGTH=8

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

    if [[ -z "${NEW_PASSWORD}" ]]; then
        logMessage "ERROR: Password parameter (\$5) is required"
        exit 1
    fi

    if [[ ${#NEW_PASSWORD} -lt ${MIN_PASSWORD_LENGTH} ]]; then
        logMessage "ERROR: Password must be at least ${MIN_PASSWORD_LENGTH} characters"
        exit 1
    fi
}

checkUserExists() {
    if ! dscl . -read "/Users/${USERNAME}" &>/dev/null; then
        logMessage "ERROR: User '${USERNAME}' does not exist"
        exit 1
    fi
}

isLocalAccount() {
    local username="$1"

    # Check if account is a mobile AD account
    if dscl . -read "/Users/${username}" OriginalAuthenticationAuthority &>/dev/null; then
        return 1
    fi

    # Check for local cached user
    if dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null | grep -q "LocalCachedUser"; then
        return 1
    fi

    return 0
}

resetPassword() {
    local username="$1"
    local password="$2"

    logMessage "Resetting password for user: ${username}"

    # Use sysadminctl to reset the password (requires admin privileges)
    if sysadminctl -resetPasswordFor "${username}" -newPassword "${password}" 2>&1 | tee -a "${LOG_FILE}"; then
        logMessage "Successfully reset password for ${username}"
        return 0
    else
        logMessage "ERROR: sysadminctl failed, trying dscl method"

        # Fallback to dscl method
        if dscl . -passwd "/Users/${username}" "${password}" 2>&1 | tee -a "${LOG_FILE}"; then
            logMessage "Successfully reset password for ${username} using dscl"
            return 0
        else
            logMessage "ERROR: Failed to reset password for ${username}"
            return 1
        fi
    fi
}

unlockAccount() {
    local username="$1"

    # Clear any password policy lockouts
    pwpolicy -u "${username}" -clearaccountpolicies 2>/dev/null

    logMessage "Cleared password policy lockouts for ${username}"
}

forcePasswordChange() {
    local username="$1"

    # Set password to expire immediately (forces change at next login)
    # This is optional and can be enabled if needed
    # pwpolicy -u "${username}" -setpolicy "newPasswordRequired=1"

    logMessage "Note: User may need to change password at next login depending on policy"
}

updateKeychainPassword() {
    local username="$1"

    # Note: The keychain password cannot be automatically updated
    # User will need to either update it manually or create a new keychain
    logMessage "WARNING: User's keychain password will not match. User may need to update keychain or create new one."
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting resetUserPassword.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if user exists
checkUserExists

# Check if local account
if ! isLocalAccount "${USERNAME}"; then
    logMessage "WARNING: User ${USERNAME} appears to be a mobile/AD account. Password reset may not work as expected."
fi

# Unlock the account first (in case it's locked)
unlockAccount "${USERNAME}"

# Reset the password
if resetPassword "${USERNAME}" "${NEW_PASSWORD}"; then
    # Note about keychain
    updateKeychainPassword "${USERNAME}"

    logMessage "Password reset completed for ${USERNAME}"
    logMessage "Script completed successfully"
    exit 0
else
    logMessage "Script failed"
    exit 1
fi
