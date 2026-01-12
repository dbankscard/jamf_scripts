#!/bin/bash

#purpose: Clear all pending print jobs using cancel -a
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to get print queue status
getPrintQueueCount() {
    local jobCount
    jobCount=$(lpstat -o 2>/dev/null | wc -l | tr -d ' ')
    echo "$jobCount"
}

# Function to list printers
listPrinters() {
    lpstat -p 2>/dev/null | awk '{print $2}'
}

# Main execution
logMessage "Starting print queue cleanup..."

# Check if CUPS is running
if ! pgrep -x cupsd >/dev/null 2>&1; then
    logMessage "Warning: CUPS service (cupsd) does not appear to be running"
fi

# Get initial queue count
initialQueueCount=$(getPrintQueueCount)
logMessage "Current print jobs in queue: ${initialQueueCount}"

# List current printers
printerList=$(listPrinters)
if [[ -n "$printerList" ]]; then
    logMessage "Configured printers:"
    while IFS= read -r printer; do
        logMessage "  - ${printer}"
    done <<< "$printerList"
else
    logMessage "No printers currently configured"
fi

# Clear all print jobs
if [[ "$initialQueueCount" -eq 0 ]]; then
    logMessage "No print jobs to clear"
    exit 0
fi

logMessage "Cancelling all print jobs..."

# Cancel all jobs for all printers
cancelOutput=$(cancel -a 2>&1)
cancelExitCode=$?

if [[ $cancelExitCode -eq 0 ]]; then
    logMessage "Cancel command executed successfully"
else
    logMessage "Warning: Cancel command returned exit code ${cancelExitCode}"
    logMessage "Output: ${cancelOutput}"
fi

# Also try to cancel jobs for each specific printer
if [[ -n "$printerList" ]]; then
    while IFS= read -r printer; do
        cancel -a "$printer" 2>/dev/null
    done <<< "$printerList"
fi

# Wait briefly for queue to clear
sleep 2

# Verify queue is cleared
finalQueueCount=$(getPrintQueueCount)
logMessage "Print jobs remaining in queue: ${finalQueueCount}"

if [[ "$finalQueueCount" -eq 0 ]]; then
    logMessage "Print queue cleared successfully"
    logMessage "Cleared ${initialQueueCount} print job(s)"
    exit 0
elif [[ "$finalQueueCount" -lt "$initialQueueCount" ]]; then
    clearedCount=$((initialQueueCount - finalQueueCount))
    logMessage "Partially cleared print queue"
    logMessage "Cleared ${clearedCount} of ${initialQueueCount} print job(s)"
    logMessage "Some jobs may be actively printing or stuck"
    exit 1
else
    logMessage "Warning: Could not clear print queue"
    logMessage "Jobs may be locked or actively printing"
    exit 1
fi
