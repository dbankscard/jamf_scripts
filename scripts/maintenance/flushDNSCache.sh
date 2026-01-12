#!/bin/bash

#purpose: Flush DNS cache using dscacheutil and mDNSResponder
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
    local osVersion
    osVersion=$(sw_vers -productVersion)
    echo "$osVersion"
}

# Main execution
logMessage "Starting DNS cache flush..."

# Get macOS version for reference
macOSVersion=$(getMacOSVersion)
logMessage "macOS version: ${macOSVersion}"

# Track success
flushSuccess=0

# Flush DNS cache using dscacheutil
logMessage "Flushing DNS cache with dscacheutil..."
if dscacheutil -flushcache 2>/dev/null; then
    logMessage "dscacheutil cache flush completed"
else
    logMessage "Warning: dscacheutil flush may have encountered an issue"
    flushSuccess=1
fi

# Restart mDNSResponder to clear DNS cache
# This method works on macOS 10.10.4 and later
logMessage "Restarting mDNSResponder service..."
if killall -HUP mDNSResponder 2>/dev/null; then
    logMessage "mDNSResponder restart signal sent successfully"
else
    logMessage "Warning: Could not send restart signal to mDNSResponder"
    flushSuccess=1
fi

# Also clear MDNS cache (supplementary)
logMessage "Clearing MDNS cache..."
if dscacheutil -flushcache 2>/dev/null; then
    logMessage "MDNS cache flush completed"
fi

# For older macOS versions, also try discoveryutil if available
if command -v discoveryutil &>/dev/null; then
    logMessage "Clearing discoveryutil caches (legacy)..."
    discoveryutil mdnsflushcache 2>/dev/null
    discoveryutil udnsflushcaches 2>/dev/null
fi

# Verify mDNSResponder is running
if pgrep -x mDNSResponder >/dev/null; then
    logMessage "mDNSResponder service is running"
else
    logMessage "Warning: mDNSResponder service may not be running"
    flushSuccess=1
fi

logMessage "DNS cache flush completed"

if [[ $flushSuccess -eq 0 ]]; then
    logMessage "All DNS cache flush operations completed successfully"
    exit 0
else
    logMessage "DNS cache flush completed with some warnings"
    exit 1
fi
