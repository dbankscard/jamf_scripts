#!/bin/bash

#purpose: Check System Integrity Protection (SIP) status
#date: January 2026

# Constants
SCRIPT_NAME="checkSIPStatus"
LOG_TAG="[${SCRIPT_NAME}]"

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

# Main script
logMessage "Starting System Integrity Protection (SIP) status check..."

# Check if csrutil command exists
if [[ ! -x /usr/bin/csrutil ]]; then
    logMessage "ERROR: csrutil command not found"
    exit 1
fi

# Get SIP status
sipStatus=$(/usr/bin/csrutil status 2>&1)
exitCode=$?

if [[ ${exitCode} -ne 0 ]]; then
    logMessage "ERROR: Failed to check SIP status"
    logMessage "Error output: ${sipStatus}"
    exit 1
fi

logMessage "SIP Status Output: ${sipStatus}"

# Parse SIP status
if echo "${sipStatus}" | grep -q "enabled"; then
    logMessage "System Integrity Protection: ENABLED"

    # Check for any disabled components
    if echo "${sipStatus}" | grep -qi "disabled"; then
        logMessage "WARNING: Some SIP protections may be disabled"

        # Get detailed status if available
        detailedStatus=$(/usr/bin/csrutil status 2>&1)
        logMessage "Detailed status:"
        echo "${detailedStatus}" | while read -r line; do
            logMessage "  ${line}"
        done

        logMessage "STATUS: PARTIALLY COMPLIANT - SIP is enabled but some components may be disabled"
    else
        logMessage "STATUS: COMPLIANT - System Integrity Protection is fully enabled"
    fi

    exit 0

elif echo "${sipStatus}" | grep -q "disabled"; then
    logMessage "System Integrity Protection: DISABLED"
    logMessage "WARNING: SIP is disabled on this system"
    logMessage "STATUS: NON-COMPLIANT - SIP should be enabled for security"
    logMessage "NOTE: SIP can only be enabled/disabled from Recovery Mode"
    exit 0

elif echo "${sipStatus}" | grep -q "unknown"; then
    logMessage "System Integrity Protection: UNKNOWN"
    logMessage "WARNING: Unable to determine SIP status"
    exit 1

else
    logMessage "System Integrity Protection: UNABLE TO DETERMINE"
    logMessage "Raw status: ${sipStatus}"
    exit 1
fi
