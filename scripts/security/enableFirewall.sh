#!/bin/bash

#purpose: Enable application firewall and configure stealth mode
#date: January 2026

# Constants
SCRIPT_NAME="enableFirewall"
LOG_TAG="[${SCRIPT_NAME}]"
FIREWALL_CMD="/usr/libexec/ApplicationFirewall/socketfilterfw"

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

# Main script
logMessage "Starting firewall configuration..."

# Check for root privileges
checkRoot

# Check if firewall command exists
if [[ ! -x "${FIREWALL_CMD}" ]]; then
    logMessage "ERROR: Application Firewall command not found at ${FIREWALL_CMD}"
    exit 1
fi

# Check current firewall status
currentStatus=$(${FIREWALL_CMD} --getglobalstate 2>&1)
logMessage "Current firewall status: ${currentStatus}"

# Enable the firewall
logMessage "Enabling Application Firewall..."
enableResult=$(${FIREWALL_CMD} --setglobalstate on 2>&1)
enableExitCode=$?

if [[ ${enableExitCode} -ne 0 ]]; then
    logMessage "ERROR: Failed to enable firewall"
    logMessage "Error: ${enableResult}"
    exit 1
fi

logMessage "Firewall enabled: ${enableResult}"

# Enable stealth mode
logMessage "Enabling stealth mode..."
stealthResult=$(${FIREWALL_CMD} --setstealthmode on 2>&1)
stealthExitCode=$?

if [[ ${stealthExitCode} -ne 0 ]]; then
    logMessage "ERROR: Failed to enable stealth mode"
    logMessage "Error: ${stealthResult}"
    exit 1
fi

logMessage "Stealth mode enabled: ${stealthResult}"

# Block all incoming connections (optional - commented out as it may be too restrictive)
# logMessage "Blocking all incoming connections..."
# ${FIREWALL_CMD} --setblockall on

# Enable logging
logMessage "Enabling firewall logging..."
loggingResult=$(${FIREWALL_CMD} --setloggingmode on 2>&1)
logMessage "Logging mode: ${loggingResult}"

# Disable allow signed apps automatically (more secure)
logMessage "Configuring signed application policy..."
signedResult=$(${FIREWALL_CMD} --setallowsigned off 2>&1)
logMessage "Allow signed apps: ${signedResult}"

# Disable allow signed downloaded apps automatically
signedDownloadResult=$(${FIREWALL_CMD} --setallowsignedapp off 2>&1)
logMessage "Allow signed downloaded apps: ${signedDownloadResult}"

# Verify final configuration
logMessage "Verifying firewall configuration..."

finalGlobalState=$(${FIREWALL_CMD} --getglobalstate 2>&1)
finalStealthMode=$(${FIREWALL_CMD} --getstealthmode 2>&1)
finalLoggingMode=$(${FIREWALL_CMD} --getloggingmode 2>&1)

logMessage "Final Configuration:"
logMessage "  Global State: ${finalGlobalState}"
logMessage "  Stealth Mode: ${finalStealthMode}"
logMessage "  Logging Mode: ${finalLoggingMode}"

# Check if firewall is now enabled
if echo "${finalGlobalState}" | grep -qi "enabled"; then
    logMessage "Application Firewall configuration completed successfully"
    exit 0
else
    logMessage "ERROR: Firewall may not be properly enabled"
    exit 1
fi
