#!/bin/bash

#purpose: Reset Bluetooth module
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly BLUETOOTH_PLIST="/Library/Preferences/com.apple.Bluetooth.plist"

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to check Bluetooth status
getBluetoothStatus() {
    local status
    # Try using system_profiler to get Bluetooth info
    status=$(system_profiler SPBluetoothDataType 2>/dev/null | grep -i "Bluetooth:" | head -1)
    echo "$status"
}

# Function to check if blueutil is available (common third-party tool)
hasBlueutil() {
    command -v blueutil &>/dev/null
}

# Main execution
logMessage "Starting Bluetooth module reset..."

# Get macOS version
macOSVersion=$(sw_vers -productVersion)
logMessage "macOS version: ${macOSVersion}"

# Check current Bluetooth status
bluetoothInfo=$(getBluetoothStatus)
logMessage "Current Bluetooth status: ${bluetoothInfo:-Unknown}"

# Method 1: Use blueutil if available (most reliable method)
if hasBlueutil; then
    logMessage "Using blueutil for Bluetooth reset..."

    # Turn Bluetooth off
    logMessage "Turning Bluetooth off..."
    blueutil --power 0
    sleep 2

    # Turn Bluetooth back on
    logMessage "Turning Bluetooth on..."
    blueutil --power 1
    sleep 2

    # Verify status
    if blueutil --power | grep -q "1"; then
        logMessage "Bluetooth successfully reset and enabled"
        exit 0
    else
        logMessage "Warning: Bluetooth may not have re-enabled properly"
    fi
else
    logMessage "blueutil not found, using system methods..."
fi

# Method 2: Kill Bluetooth daemon to force reset
logMessage "Restarting Bluetooth daemon..."

# Kill the Bluetooth daemon - launchd will restart it
if pkill -HUP bluetoothd 2>/dev/null; then
    logMessage "Sent restart signal to bluetoothd"
else
    logMessage "Could not signal bluetoothd, trying alternative method..."

    # Alternative: unload and reload the Bluetooth kext (requires reboot on modern macOS)
    # On modern macOS with SIP, this is limited
    sudo killall -9 bluetoothd 2>/dev/null
fi

# Wait for daemon to restart
sleep 3

# Method 3: Reset Bluetooth preferences (more aggressive)
# This removes paired devices and settings
logMessage "Note: For a full Bluetooth reset including clearing paired devices,"
logMessage "the following command can be used (not executed by default):"
logMessage "sudo rm -rf /Library/Preferences/com.apple.Bluetooth.plist"

# Verify Bluetooth service is running
if pgrep -x bluetoothd >/dev/null 2>&1; then
    logMessage "Bluetooth daemon is running"
else
    logMessage "Warning: Bluetooth daemon may not be running"

    # Try to start the daemon via launchctl
    logMessage "Attempting to start Bluetooth via launchctl..."
    launchctl kickstart -k system/com.apple.bluetoothd 2>/dev/null
    sleep 2
fi

# Final status check
if pgrep -x bluetoothd >/dev/null 2>&1; then
    logMessage "Bluetooth module reset completed"
    logMessage "Note: You may need to re-pair Bluetooth devices"
    exit 0
else
    logMessage "Error: Bluetooth daemon could not be verified as running"
    logMessage "A system restart may be required"
    exit 1
fi
