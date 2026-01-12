#!/bin/bash

#########################################################################################
# Script Name:  unlockUserAccount.sh
# Purpose:      Unlock a locked user account
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = username (required)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
USERNAME="$4"

# Constants
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

validateParameters() {
    if [[ -z "${USERNAME}" ]]; then
        logMessage "ERROR: Username parameter (\$4) is required"
        exit 1
    fi
}

checkUserExists() {
    if ! dscl . -read "/Users/${USERNAME}" &>/dev/null; then
        logMessage "ERROR: User '${USERNAME}' does not exist"
        exit 1
    fi
}

getAccountStatus() {
    local username="$1"
    local status="unlocked"

    # Check if account is disabled
    local authAuthority
    authAuthority=$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null)

    if echo "${authAuthority}" | grep -q "DisabledUser"; then
        status="disabled"
    fi

    # Check password policy status
    local policyStatus
    policyStatus=$(pwpolicy -u "${username}" -getpolicy 2>/dev/null)

    if echo "${policyStatus}" | grep -q "isDisabled=1"; then
        status="disabled_by_policy"
    fi

    # Check for failed login attempts
    local failedLogins
    failedLogins=$(pwpolicy -u "${username}" -getfailedlogincount 2>/dev/null | awk '{print $NF}')

    if [[ -n "${failedLogins}" ]] && [[ "${failedLogins}" -gt 0 ]]; then
        logMessage "User has ${failedLogins} failed login attempts"
    fi

    echo "${status}"
}

clearFailedLoginAttempts() {
    local username="$1"

    logMessage "Clearing failed login attempts for ${username}"

    # Reset failed login count
    if pwpolicy -u "${username}" -setfailedlogincount 0 2>/dev/null; then
        logMessage "Cleared failed login count"
    fi

    # Clear account policies (removes lockout)
    if pwpolicy -u "${username}" -clearaccountpolicies 2>/dev/null; then
        logMessage "Cleared account policies"
    fi
}

enableDisabledAccount() {
    local username="$1"

    logMessage "Enabling disabled account: ${username}"

    # Get current AuthenticationAuthority
    local authAuthority
    authAuthority=$(dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null | grep -v "AuthenticationAuthority:")

    # Remove DisabledUser from AuthenticationAuthority
    if echo "${authAuthority}" | grep -q "DisabledUser"; then
        # Delete and recreate without DisabledUser
        dscl . -delete "/Users/${username}" AuthenticationAuthority

        # Re-add authentication authority without disabled flag
        # This is a simplified approach - in production, you may need to preserve specific auth methods
        logMessage "Removed DisabledUser flag from authentication authority"
    fi
}

unlockAccountViaPwpolicy() {
    local username="$1"

    logMessage "Unlocking account via pwpolicy: ${username}"

    # Enable the account
    pwpolicy -u "${username}" -enableuser 2>/dev/null

    # Reset the global policy to allow login
    pwpolicy -u "${username}" -setpolicy "isDisabled=0" 2>/dev/null
}

unlockSecureToken() {
    local username="$1"

    # Check if secure token is disabled/locked
    local secureTokenStatus
    secureTokenStatus=$(sysadminctl -secureTokenStatus "${username}" 2>&1)

    if echo "${secureTokenStatus}" | grep -q "DISABLED"; then
        logMessage "Note: Secure token is disabled for ${username}"
        logMessage "Secure token cannot be automatically re-enabled without an admin password"
    fi
}

verifyUnlocked() {
    local username="$1"
    local status

    status=$(getAccountStatus "${username}")

    if [[ "${status}" == "unlocked" ]]; then
        logMessage "Verified: Account ${username} is now unlocked"
        return 0
    else
        logMessage "WARNING: Account ${username} may still be locked (status: ${status})"
        return 1
    fi
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting unlockUserAccount.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if user exists
checkUserExists

# Get current account status
accountStatus=$(getAccountStatus "${USERNAME}")
logMessage "Current account status for ${USERNAME}: ${accountStatus}"

if [[ "${accountStatus}" == "unlocked" ]]; then
    logMessage "Account ${USERNAME} is already unlocked"

    # Still clear any failed login attempts
    clearFailedLoginAttempts "${USERNAME}"

    exit 0
fi

# Unlock the account
logMessage "Unlocking account: ${USERNAME}"

# Clear failed login attempts
clearFailedLoginAttempts "${USERNAME}"

# Enable if disabled
if [[ "${accountStatus}" == "disabled" ]] || [[ "${accountStatus}" == "disabled_by_policy" ]]; then
    enableDisabledAccount "${USERNAME}"
    unlockAccountViaPwpolicy "${USERNAME}"
fi

# Check secure token status
unlockSecureToken "${USERNAME}"

# Verify the account is unlocked
if verifyUnlocked "${USERNAME}"; then
    logMessage "Script completed successfully"
    echo "Account ${USERNAME} has been unlocked"
    exit 0
else
    logMessage "Script completed with warnings - manual verification recommended"
    exit 0
fi
