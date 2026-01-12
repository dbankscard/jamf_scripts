#!/bin/bash

#purpose: Check disk usage and alert if available space is below threshold
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly DEFAULT_THRESHOLD_GB=10
readonly BYTES_PER_GB=1073741824

# Jamf parameter $4 for custom threshold (in GB)
customThreshold="$4"

# Set threshold - use custom if provided and valid, otherwise use default
if [[ -n "$customThreshold" ]] && [[ "$customThreshold" =~ ^[0-9]+$ ]]; then
    thresholdGB="$customThreshold"
else
    thresholdGB="$DEFAULT_THRESHOLD_GB"
fi

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to convert bytes to human-readable format
bytesToHuman() {
    local bytes="$1"
    if [[ $bytes -ge 1099511627776 ]]; then
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc) TB"
    elif [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    else
        echo "${bytes} bytes"
    fi
}

# Main execution
logMessage "Starting disk space check..."
logMessage "Threshold set to ${thresholdGB} GB"

# Get boot volume mount point
bootVolume=$(df / | tail -1 | awk '{print $NF}')

# Get available space in bytes using diskutil
diskInfo=$(diskutil info / 2>/dev/null)
if [[ $? -ne 0 ]]; then
    logMessage "Error: Unable to get disk information"
    exit 1
fi

# Extract available space (Container Free Space for APFS or Free Space for HFS+)
availableBytes=$(echo "$diskInfo" | grep -E "(Container Free Space|Available Space|Free Space)" | head -1 | awk -F'(' '{print $2}' | awk '{print $1}')

if [[ -z "$availableBytes" ]]; then
    # Fallback: use df command
    availableKB=$(df -k / | tail -1 | awk '{print $4}')
    availableBytes=$((availableKB * 1024))
fi

if [[ -z "$availableBytes" ]] || [[ ! "$availableBytes" =~ ^[0-9]+$ ]]; then
    logMessage "Error: Unable to determine available disk space"
    exit 1
fi

# Calculate threshold in bytes
thresholdBytes=$((thresholdGB * BYTES_PER_GB))

# Get total disk size
totalBytes=$(echo "$diskInfo" | grep -E "(Total Space|Disk Size)" | head -1 | awk -F'(' '{print $2}' | awk '{print $1}')

# Calculate percentage used
if [[ -n "$totalBytes" ]] && [[ "$totalBytes" =~ ^[0-9]+$ ]] && [[ "$totalBytes" -gt 0 ]]; then
    usedBytes=$((totalBytes - availableBytes))
    percentUsed=$((usedBytes * 100 / totalBytes))
else
    percentUsed="N/A"
fi

# Log current disk status
availableHuman=$(bytesToHuman "$availableBytes")
logMessage "Boot volume: ${bootVolume}"
logMessage "Available space: ${availableHuman}"
logMessage "Disk usage: ${percentUsed}%"

# Check if below threshold
if [[ $availableBytes -lt $thresholdBytes ]]; then
    logMessage "WARNING: Disk space is below threshold!"
    logMessage "Available: ${availableHuman} | Threshold: ${thresholdGB} GB"
    logMessage "Action required: Free up disk space on this Mac"
    exit 1
else
    logMessage "Disk space check passed"
    logMessage "Available space (${availableHuman}) is above threshold (${thresholdGB} GB)"
    exit 0
fi
