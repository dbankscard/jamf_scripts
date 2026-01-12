#!/bin/bash

#purpose: Verify Gatekeeper is enabled and report status
#date: January 2026

# Constants
SCRIPT_NAME="checkGatekeeper"
LOG_TAG="[${SCRIPT_NAME}]"

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

# Main script
logMessage "Starting Gatekeeper status check..."

# Check if spctl command exists
if [[ ! -x /usr/sbin/spctl ]]; then
    logMessage "ERROR: spctl command not found"
    exit 1
fi

# Get Gatekeeper status
gatekeeperStatus=$(/usr/sbin/spctl --status 2>&1)
exitCode=$?

if [[ ${exitCode} -ne 0 ]]; then
    logMessage "ERROR: Failed to check Gatekeeper status"
    logMessage "Error output: ${gatekeeperStatus}"
    exit 1
fi

# Check Gatekeeper assessment status
if echo "${gatekeeperStatus}" | grep -q "assessments enabled"; then
    logMessage "Gatekeeper Status: ENABLED"

    # Get detailed Gatekeeper information
    logMessage "Checking Gatekeeper details..."

    # Check developer ID status
    devIdStatus=$(/usr/sbin/spctl --status --verbose 2>&1 || true)
    if [[ -n "${devIdStatus}" ]]; then
        logMessage "Verbose status: ${devIdStatus}"
    fi

    # Check if notarization is enforced (macOS 10.15+)
    osVersion=$(/usr/bin/sw_vers -productVersion)
    majorVersion=$(echo "${osVersion}" | cut -d. -f1)

    if [[ ${majorVersion} -ge 10 ]]; then
        logMessage "macOS version ${osVersion} - Notarization enforcement is active"
    fi

    logMessage "Gatekeeper check completed successfully"
    logMessage "STATUS: COMPLIANT - Gatekeeper is enabled"
    exit 0

elif echo "${gatekeeperStatus}" | grep -q "assessments disabled"; then
    logMessage "Gatekeeper Status: DISABLED"
    logMessage "WARNING: Gatekeeper is disabled on this system"
    logMessage "STATUS: NON-COMPLIANT - Gatekeeper should be enabled for security"
    exit 0

else
    logMessage "Gatekeeper Status: UNKNOWN"
    logMessage "Raw status: ${gatekeeperStatus}"
    exit 1
fi
