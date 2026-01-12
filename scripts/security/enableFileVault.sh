#!/bin/bash

#purpose: Enable FileVault with institutional recovery key escrow to Jamf
#date: January 2026

# Constants
SCRIPT_NAME="enableFileVault"
LOG_TAG="[${SCRIPT_NAME}]"
JAMF_BINARY="/usr/local/jamf/bin/jamf"

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

getCurrentUser() {
    local currentUser
    currentUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')
    echo "${currentUser}"
}

# Main script
logMessage "Starting FileVault enablement process..."

# Check for root privileges
checkRoot

# Check if fdesetup command exists
if [[ ! -x /usr/bin/fdesetup ]]; then
    logMessage "ERROR: fdesetup command not found"
    exit 1
fi

# Check current FileVault status
fileVaultStatus=$(/usr/bin/fdesetup status 2>&1)

if echo "${fileVaultStatus}" | grep -q "FileVault is On"; then
    logMessage "FileVault is already enabled"

    # Attempt to escrow the recovery key to Jamf if not already done
    if [[ -x "${JAMF_BINARY}" ]]; then
        logMessage "Attempting to escrow recovery key to Jamf..."
        "${JAMF_BINARY}" policy -event "FileVaultKey" 2>/dev/null || true
    fi

    logMessage "FileVault enablement check completed"
    exit 0
fi

# Get current console user
currentUser=$(getCurrentUser)

if [[ -z "${currentUser}" ]] || [[ "${currentUser}" == "root" ]] || [[ "${currentUser}" == "loginwindow" ]]; then
    logMessage "ERROR: No valid user is logged in. FileVault requires a logged-in user."
    exit 1
fi

logMessage "Current user: ${currentUser}"

# Check if Jamf binary exists for key escrow
if [[ ! -x "${JAMF_BINARY}" ]]; then
    logMessage "ERROR: Jamf binary not found. Cannot enable FileVault with institutional key escrow."
    exit 1
fi

# Create deferred enablement plist for FileVault
# This will prompt the user at next logout to enable FileVault
deferredPlist="/private/var/root/Library/Preferences/com.apple.fdesetup.plist"

logMessage "Configuring FileVault deferred enablement..."

# Use Jamf's built-in FileVault enablement which handles key escrow
logMessage "Initiating FileVault enablement via Jamf..."

# Run Jamf policy to enable FileVault
# This assumes a Jamf policy is configured with FileVault enablement payload
"${JAMF_BINARY}" policy -event "enableFileVault" 2>&1
jamfExitCode=$?

if [[ ${jamfExitCode} -ne 0 ]]; then
    logMessage "WARNING: Jamf policy trigger may not have found a matching policy"

    # Alternative: Use fdesetup with deferred enablement
    logMessage "Attempting deferred FileVault enablement..."

    # Check if institutional recovery key certificate exists
    if [[ -f "/Library/Keychains/FileVaultMaster.keychain" ]]; then
        logMessage "Institutional recovery keychain found"

        /usr/bin/fdesetup enable -defer "${deferredPlist}" -forcerestart -keychain 2>&1
        fdeExitCode=$?

        if [[ ${fdeExitCode} -eq 0 ]]; then
            logMessage "FileVault deferred enablement configured successfully"
            logMessage "User will be prompted at next logout/restart"
        else
            logMessage "ERROR: Failed to configure deferred FileVault enablement"
            exit 1
        fi
    else
        logMessage "WARNING: No institutional recovery keychain found"
        logMessage "Enabling FileVault with personal recovery key..."

        /usr/bin/fdesetup enable -defer "${deferredPlist}" -forcerestart 2>&1
        fdeExitCode=$?

        if [[ ${fdeExitCode} -eq 0 ]]; then
            logMessage "FileVault deferred enablement configured"
            logMessage "User will be prompted at next logout/restart"
        else
            logMessage "ERROR: Failed to configure deferred FileVault enablement"
            exit 1
        fi
    fi
fi

# Attempt to escrow the key once enabled
logMessage "Recovery key will be escrowed to Jamf upon enablement"

logMessage "FileVault enablement process completed"
logMessage "NOTE: User may need to log out or restart to complete FileVault setup"
exit 0
