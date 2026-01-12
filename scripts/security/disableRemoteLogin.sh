#!/bin/bash

#purpose: Disable SSH/Remote Login
#date: January 2026

# Constants
SCRIPT_NAME="disableRemoteLogin"
LOG_TAG="[${SCRIPT_NAME}]"

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

getRemoteLoginStatus() {
    local status
    status=$(/usr/sbin/systemsetup -getremotelogin 2>&1 || echo "")
    echo "${status}"
}

# Main script
logMessage "Starting Remote Login (SSH) disable process..."

# Check for root privileges
checkRoot

# Check current Remote Login status
currentStatus=$(getRemoteLoginStatus)
logMessage "Current Remote Login status: ${currentStatus}"

# Check if already disabled
if echo "${currentStatus}" | grep -qi "off"; then
    logMessage "Remote Login (SSH) is already disabled"
    logMessage "No action required"
    exit 0
fi

# Disable Remote Login using systemsetup
logMessage "Disabling Remote Login (SSH)..."

# The -f flag forces the change without prompting
disableResult=$(/usr/sbin/systemsetup -f -setremotelogin off 2>&1)
disableExitCode=$?

if [[ ${disableExitCode} -ne 0 ]]; then
    logMessage "WARNING: systemsetup command may have encountered an issue"
    logMessage "Result: ${disableResult}"

    # Alternative method: stop and unload the SSH service directly
    logMessage "Attempting alternative method via launchctl..."

    # Stop the SSH service
    /bin/launchctl unload -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true

    # For newer macOS versions, also try bootout
    /bin/launchctl bootout system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
fi

# Verify the change
sleep 1  # Brief pause to allow changes to take effect

verifyStatus=$(getRemoteLoginStatus)
logMessage "Verification status: ${verifyStatus}"

# Additional verification using launchctl
sshServiceCheck=$(/bin/launchctl list 2>/dev/null | grep -c "com.openssh.sshd" || echo "0")

if echo "${verifyStatus}" | grep -qi "off"; then
    logMessage "Remote Login (SSH) has been successfully disabled"
    logMessage "STATUS: SUCCESS"
    exit 0
elif [[ "${sshServiceCheck}" -eq 0 ]]; then
    logMessage "SSH service is not running"
    logMessage "Remote Login appears to be disabled"
    logMessage "STATUS: SUCCESS"
    exit 0
else
    logMessage "WARNING: Unable to verify Remote Login is disabled"
    logMessage "SSH service check returned: ${sshServiceCheck}"

    # Check if SSH port is listening
    sshPortCheck=$(/usr/sbin/lsof -i :22 2>/dev/null | grep -c LISTEN || echo "0")

    if [[ "${sshPortCheck}" -eq 0 ]]; then
        logMessage "No service listening on SSH port (22)"
        logMessage "Remote Login is effectively disabled"
        exit 0
    else
        logMessage "ERROR: SSH port appears to still be active"
        exit 1
    fi
fi
