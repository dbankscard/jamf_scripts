#!/bin/bash

#purpose: Run First Aid on boot volume using diskutil
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to get boot volume identifier
getBootVolumeIdentifier() {
    local bootDisk
    bootDisk=$(diskutil info / | grep "Device Identifier" | awk '{print $NF}')
    echo "$bootDisk"
}

# Function to get boot volume name
getBootVolumeName() {
    local volumeName
    volumeName=$(diskutil info / | grep "Volume Name" | sed 's/.*Volume Name: *//')
    echo "$volumeName"
}

# Main execution
logMessage "Starting disk First Aid..."

# Get boot volume information
bootVolumeId=$(getBootVolumeIdentifier)
bootVolumeName=$(getBootVolumeName)

if [[ -z "$bootVolumeId" ]]; then
    logMessage "Error: Could not determine boot volume identifier"
    exit 1
fi

logMessage "Boot volume: ${bootVolumeName} (${bootVolumeId})"

# Check if running on APFS or HFS+
fileSystem=$(diskutil info / | grep "Type (Bundle)" | awk '{print $NF}')
if [[ -z "$fileSystem" ]]; then
    fileSystem=$(diskutil info / | grep "File System" | awk '{print $NF}')
fi

logMessage "File system: ${fileSystem}"

# Note: On modern macOS with SIP enabled, running First Aid on the boot volume
# while booted has limitations. Full disk repair requires Recovery Mode.
logMessage "Note: For complete disk repair, boot to Recovery Mode"
logMessage "Running First Aid verification on boot volume..."

# Run diskutil verifyVolume first (non-destructive check)
logMessage "Verifying volume integrity..."
verifyOutput=$(diskutil verifyVolume / 2>&1)
verifyExitCode=$?

if [[ $verifyExitCode -eq 0 ]]; then
    logMessage "Volume verification completed successfully"
    logMessage "No errors detected on boot volume"
else
    logMessage "Volume verification found issues or could not complete"
    logMessage "Verification output: ${verifyOutput}"

    # Attempt repair if verification found issues
    logMessage "Attempting to repair volume..."
    repairOutput=$(diskutil repairVolume / 2>&1)
    repairExitCode=$?

    if [[ $repairExitCode -eq 0 ]]; then
        logMessage "Volume repair completed successfully"
    else
        logMessage "Warning: Volume repair could not complete all operations"
        logMessage "Repair output: ${repairOutput}"
        logMessage "Recommendation: Boot to Recovery Mode for full disk repair"
    fi
fi

# For APFS containers, also check the container
if [[ "$fileSystem" == "apfs" ]] || [[ "$fileSystem" == "APFS" ]]; then
    containerRef=$(diskutil info / | grep "APFS Container Reference" | awk '{print $NF}')

    if [[ -n "$containerRef" ]]; then
        logMessage "Checking APFS container ${containerRef}..."

        # Verify APFS container
        containerVerify=$(diskutil verifyDisk "$containerRef" 2>&1)
        if [[ $? -eq 0 ]]; then
            logMessage "APFS container verification completed"
        else
            logMessage "Warning: APFS container verification reported issues"
            logMessage "For full container repair, use Recovery Mode"
        fi
    fi
fi

logMessage "First Aid process completed"
logMessage "For complete disk maintenance, consider running First Aid from Recovery Mode"

exit 0
