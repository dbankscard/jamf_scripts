#!/bin/bash

#purpose: Kill and restart Dock process
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly DOCK_PROCESS="Dock"

# Get the currently logged-in user
currentUser=$(stat -f "%Su" /dev/console)

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to check if Dock is running
isDockRunning() {
    if pgrep -x "$DOCK_PROCESS" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main execution
logMessage "Starting Dock restart..."

# Verify a user is logged in
if [[ "$currentUser" == "root" ]] || [[ "$currentUser" == "loginwindow" ]] || [[ -z "$currentUser" ]]; then
    logMessage "Error: No user is currently logged in at the GUI"
    exit 1
fi

logMessage "Current user: ${currentUser}"

# Check if Dock is currently running
if isDockRunning; then
    dockPID=$(pgrep -x "$DOCK_PROCESS")
    logMessage "Dock is running with PID: ${dockPID}"
else
    logMessage "Warning: Dock process not found, it may already be stopped"
fi

# Kill the Dock process
# The Dock will automatically restart due to launchd
logMessage "Killing Dock process..."
killall "$DOCK_PROCESS" 2>/dev/null

# Wait briefly for Dock to restart
sleep 2

# Verify Dock has restarted
if isDockRunning; then
    newDockPID=$(pgrep -x "$DOCK_PROCESS")
    logMessage "Dock successfully restarted with PID: ${newDockPID}"
    logMessage "Dock restart completed successfully"
    exit 0
else
    logMessage "Warning: Dock may not have restarted automatically"

    # Try to start Dock manually via launchd
    logMessage "Attempting to start Dock via launchd..."
    sudo -u "$currentUser" /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock &

    sleep 2

    if isDockRunning; then
        logMessage "Dock started successfully"
        exit 0
    else
        logMessage "Error: Could not restart Dock"
        exit 1
    fi
fi
