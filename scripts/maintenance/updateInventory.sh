#!/bin/bash

#purpose: Force Jamf inventory update using jamf recon
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly JAMF_BINARY="/usr/local/bin/jamf"

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Main execution
logMessage "Starting Jamf inventory update..."

# Check if Jamf binary exists
if [[ ! -x "$JAMF_BINARY" ]]; then
    logMessage "Error: Jamf binary not found at ${JAMF_BINARY}"
    logMessage "This Mac may not be enrolled in Jamf Pro"
    exit 1
fi

# Verify Jamf Pro enrollment
enrollmentCheck=$("$JAMF_BINARY" checkJSSConnection 2>&1)
if [[ $? -ne 0 ]]; then
    logMessage "Error: Unable to connect to Jamf Pro server"
    logMessage "Connection check output: ${enrollmentCheck}"
    exit 1
fi

logMessage "Jamf Pro connection verified"

# Run recon to update inventory
logMessage "Running jamf recon to update inventory..."
reconOutput=$("$JAMF_BINARY" recon 2>&1)
reconExitCode=$?

if [[ $reconExitCode -eq 0 ]]; then
    logMessage "Inventory update completed successfully"

    # Extract useful information from recon output
    if echo "$reconOutput" | grep -q "Submitting data to"; then
        serverUrl=$(echo "$reconOutput" | grep "Submitting data to" | awk '{print $NF}')
        logMessage "Data submitted to: ${serverUrl}"
    fi

    exit 0
else
    logMessage "Error: Inventory update failed with exit code ${reconExitCode}"
    logMessage "Recon output: ${reconOutput}"
    exit 1
fi
