#!/bin/bash

#purpose: Rebuild Spotlight index for boot volume
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly SPOTLIGHT_STORE="/.Spotlight-V100"

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to get Spotlight indexing status
getSpotlightStatus() {
    mdutil -s / 2>&1
}

# Function to check if Spotlight is currently indexing
isSpotlightIndexing() {
    local status
    status=$(mdutil -s / 2>&1)
    if echo "$status" | grep -qi "indexing"; then
        return 0
    else
        return 1
    fi
}

# Main execution
logMessage "Starting Spotlight index rebuild..."

# Get boot volume information
bootVolume=$(df / | tail -1 | awk '{print $NF}')
logMessage "Boot volume: ${bootVolume}"

# Check current Spotlight status
currentStatus=$(getSpotlightStatus)
logMessage "Current Spotlight status:"
echo "$currentStatus" | while IFS= read -r line; do
    logMessage "  ${line}"
done

# Check if Spotlight indexing is enabled
if echo "$currentStatus" | grep -qi "indexing disabled"; then
    logMessage "Warning: Spotlight indexing is currently disabled"
    logMessage "Enabling Spotlight indexing..."

    mdutil -i on / 2>/dev/null
    if [[ $? -ne 0 ]]; then
        logMessage "Error: Could not enable Spotlight indexing"
        exit 1
    fi
fi

# Turn off indexing first (required before erasing)
logMessage "Temporarily disabling Spotlight indexing..."
mdutil -i off / 2>/dev/null

# Erase the existing Spotlight index
logMessage "Erasing existing Spotlight index..."
eraseOutput=$(mdutil -E / 2>&1)
eraseExitCode=$?

if [[ $eraseExitCode -ne 0 ]]; then
    logMessage "Warning: mdutil -E returned exit code ${eraseExitCode}"
    logMessage "Output: ${eraseOutput}"
fi

# Re-enable indexing to start the rebuild
logMessage "Re-enabling Spotlight indexing to start rebuild..."
enableOutput=$(mdutil -i on / 2>&1)
enableExitCode=$?

if [[ $enableExitCode -ne 0 ]]; then
    logMessage "Error: Could not re-enable Spotlight indexing"
    logMessage "Output: ${enableOutput}"
    exit 1
fi

# Wait briefly and check status
sleep 3

# Verify indexing has started
newStatus=$(getSpotlightStatus)
logMessage "New Spotlight status:"
echo "$newStatus" | while IFS= read -r line; do
    logMessage "  ${line}"
done

if echo "$newStatus" | grep -qi "indexing enabled" || echo "$newStatus" | grep -qi "indexing"; then
    logMessage "Spotlight index rebuild initiated successfully"
    logMessage ""
    logMessage "Note: The indexing process will continue in the background"
    logMessage "This may take several hours depending on the amount of data"
    logMessage "You can check progress with: mdutil -s /"
    logMessage "Or in System Settings > Siri & Spotlight"
    exit 0
else
    logMessage "Warning: Spotlight indexing status could not be verified"
    logMessage "Please check manually with: mdutil -s /"
    exit 1
fi
