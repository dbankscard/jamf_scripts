#!/bin/bash

#########################################################################################
# Script Name:  hideUserAccount.sh
# Purpose:      Hide user account from login window
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
LOGIN_WINDOW_PLIST="/Library/Preferences/com.apple.loginwindow.plist"

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

isUserHidden() {
    local username="$1"

    # Check if user is in HiddenUsersList
    local hiddenUsers
    hiddenUsers=$(/usr/libexec/PlistBuddy -c "Print :HiddenUsersList" "${LOGIN_WINDOW_PLIST}" 2>/dev/null)

    if echo "${hiddenUsers}" | grep -q "${username}"; then
        return 0
    fi

    # Also check IsHidden attribute
    local isHidden
    isHidden=$(dscl . -read "/Users/${username}" IsHidden 2>/dev/null | awk '{print $2}')

    if [[ "${isHidden}" == "1" ]]; then
        return 0
    fi

    return 1
}

hideUserFromLoginWindow() {
    local username="$1"

    logMessage "Hiding user ${username} from login window"

    # Method 1: Set IsHidden attribute in user record
    if dscl . -create "/Users/${username}" IsHidden 1; then
        logMessage "Set IsHidden attribute for ${username}"
    else
        logMessage "WARNING: Could not set IsHidden attribute"
    fi

    # Method 2: Add to HiddenUsersList in loginwindow preferences
    # First check if HiddenUsersList exists
    if ! /usr/libexec/PlistBuddy -c "Print :HiddenUsersList" "${LOGIN_WINDOW_PLIST}" &>/dev/null; then
        # Create the array if it doesn't exist
        /usr/libexec/PlistBuddy -c "Add :HiddenUsersList array" "${LOGIN_WINDOW_PLIST}" 2>/dev/null
        logMessage "Created HiddenUsersList array"
    fi

    # Check if user is already in the list
    local index=0
    local found=false
    while true; do
        local existingUser
        existingUser=$(/usr/libexec/PlistBuddy -c "Print :HiddenUsersList:${index}" "${LOGIN_WINDOW_PLIST}" 2>/dev/null)

        if [[ -z "${existingUser}" ]]; then
            break
        fi

        if [[ "${existingUser}" == "${username}" ]]; then
            found=true
            break
        fi

        ((index++))
    done

    if [[ "${found}" == "false" ]]; then
        /usr/libexec/PlistBuddy -c "Add :HiddenUsersList: string ${username}" "${LOGIN_WINDOW_PLIST}"
        logMessage "Added ${username} to HiddenUsersList"
    else
        logMessage "User ${username} already in HiddenUsersList"
    fi

    return 0
}

hideHomeDirectory() {
    local username="$1"
    local homeDir

    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

    if [[ -d "${homeDir}" ]]; then
        # Set hidden flag on home directory
        chflags hidden "${homeDir}"
        logMessage "Set hidden flag on home directory: ${homeDir}"
    fi
}

verifyHidden() {
    local username="$1"

    if isUserHidden "${username}"; then
        logMessage "Verified: User ${username} is now hidden"
        return 0
    else
        logMessage "WARNING: User ${username} may not be fully hidden"
        return 1
    fi
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting hideUserAccount.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if user exists
checkUserExists

# Check if already hidden
if isUserHidden "${USERNAME}"; then
    logMessage "User ${USERNAME} is already hidden from login window"
    exit 0
fi

# Hide the user from login window
if hideUserFromLoginWindow "${USERNAME}"; then
    # Optionally hide the home directory as well
    hideHomeDirectory "${USERNAME}"

    # Verify the user is hidden
    verifyHidden "${USERNAME}"

    logMessage "Script completed successfully"
    echo "User ${USERNAME} has been hidden from the login window"
    echo "To unhide, run: dscl . -delete /Users/${USERNAME} IsHidden"
    exit 0
else
    logMessage "Script failed"
    exit 1
fi
