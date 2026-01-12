#!/bin/bash

#purpose: Check for available macOS software updates
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to get macOS version
getMacOSVersion() {
    sw_vers -productVersion
}

# Main execution
logMessage "Starting software update check..."

# Get current macOS version
currentVersion=$(getMacOSVersion)
logMessage "Current macOS version: ${currentVersion}"

# Check for software updates using softwareupdate
logMessage "Checking for available software updates..."
logMessage "This may take a few minutes..."

# Run softwareupdate to list available updates
updateList=$(softwareupdate --list 2>&1)
updateExitCode=$?

# Check if the command succeeded
if [[ $updateExitCode -ne 0 ]]; then
    logMessage "Warning: softwareupdate command returned exit code ${updateExitCode}"
fi

# Parse the output
if echo "$updateList" | grep -q "No new software available"; then
    logMessage "No software updates available"
    logMessage "System is up to date"
    exit 0
fi

# Check for available updates
if echo "$updateList" | grep -q "Software Update found"; then
    logMessage "Software updates are available:"
    echo ""

    # Extract and display update information
    updateCount=0
    restartRequired=false

    while IFS= read -r line; do
        # Look for update labels (lines starting with *)
        if [[ "$line" == \** ]]; then
            updateName=$(echo "$line" | sed 's/^\* //')
            logMessage "  - ${updateName}"
            ((updateCount++))
        fi

        # Check if restart is required
        if echo "$line" | grep -qi "restart"; then
            restartRequired=true
        fi
    done <<< "$updateList"

    echo ""
    logMessage "Total updates available: ${updateCount}"

    if [[ "$restartRequired" == true ]]; then
        logMessage "Note: One or more updates require a restart"
    fi

    # Provide recommended actions
    logMessage ""
    logMessage "Recommended actions:"
    logMessage "  - To download and install all updates: sudo softwareupdate --install --all"
    logMessage "  - To download only: sudo softwareupdate --download --all"
    logMessage "  - To install recommended updates: sudo softwareupdate --install --recommended"

    exit 0
else
    # Check if there's any other output indicating updates
    if echo "$updateList" | grep -qi "available"; then
        logMessage "Software update information:"
        echo "$updateList"
        exit 0
    else
        logMessage "No software updates found"
        logMessage "Raw output: ${updateList}"
        exit 0
    fi
fi
