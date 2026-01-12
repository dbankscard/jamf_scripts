#!/bin/bash

#purpose: Check if FileVault is enabled and report encryption status
#date: January 2026

# Constants
SCRIPT_NAME="checkFileVaultStatus"
LOG_TAG="[${SCRIPT_NAME}]"

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

# Main script
logMessage "Starting FileVault status check..."

# Check if fdesetup command exists
if [[ ! -x /usr/bin/fdesetup ]]; then
    logMessage "ERROR: fdesetup command not found"
    exit 1
fi

# Get FileVault status
fileVaultStatus=$(/usr/bin/fdesetup status 2>&1)
exitCode=$?

if [[ ${exitCode} -ne 0 ]]; then
    logMessage "ERROR: Failed to check FileVault status"
    exit 1
fi

# Check if FileVault is on or off
if echo "${fileVaultStatus}" | grep -q "FileVault is On"; then
    logMessage "FileVault Status: ENABLED"

    # Check encryption progress if applicable
    encryptionStatus=$(/usr/bin/fdesetup status | grep -i "encryption" || true)
    if [[ -n "${encryptionStatus}" ]]; then
        logMessage "Encryption Status: ${encryptionStatus}"
    fi

    # Get list of enabled users
    enabledUsers=$(/usr/bin/fdesetup list 2>/dev/null || true)
    if [[ -n "${enabledUsers}" ]]; then
        logMessage "FileVault Enabled Users:"
        echo "${enabledUsers}" | while read -r user; do
            logMessage "  - ${user}"
        done
    fi

    logMessage "FileVault check completed successfully"
    exit 0

elif echo "${fileVaultStatus}" | grep -q "FileVault is Off"; then
    logMessage "FileVault Status: DISABLED"
    logMessage "WARNING: FileVault encryption is not enabled on this system"
    exit 0

else
    logMessage "FileVault Status: UNKNOWN"
    logMessage "Raw status: ${fileVaultStatus}"
    exit 1
fi
