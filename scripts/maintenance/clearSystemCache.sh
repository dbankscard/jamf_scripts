#!/bin/bash

#purpose: Clear system caches from /Library/Caches and ~/Library/Caches
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly SYSTEM_CACHE_DIR="/Library/Caches"

# Get the currently logged-in user
currentUser=$(stat -f "%Su" /dev/console)
userHome=$(dscl . -read /Users/"$currentUser" NFSHomeDirectory | awk '{print $2}')
userCacheDir="${userHome}/Library/Caches"

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to clear cache directory
clearCacheDir() {
    local cacheDir="$1"
    local description="$2"

    if [[ -d "$cacheDir" ]]; then
        logMessage "Clearing ${description} at ${cacheDir}..."

        # Remove contents but keep the directory
        if rm -rf "${cacheDir:?}"/* 2>/dev/null; then
            logMessage "Successfully cleared ${description}"
            return 0
        else
            logMessage "Warning: Some items in ${description} could not be removed"
            return 1
        fi
    else
        logMessage "Warning: ${description} directory does not exist at ${cacheDir}"
        return 1
    fi
}

# Main execution
logMessage "Starting system cache cleanup..."

# Track overall success
overallSuccess=0

# Clear system-level caches
if [[ -d "$SYSTEM_CACHE_DIR" ]]; then
    clearCacheDir "$SYSTEM_CACHE_DIR" "system cache"
    [[ $? -ne 0 ]] && overallSuccess=1
else
    logMessage "System cache directory not found"
fi

# Clear user-level caches if a user is logged in
if [[ "$currentUser" != "root" ]] && [[ "$currentUser" != "loginwindow" ]]; then
    logMessage "Current user: ${currentUser}"

    if [[ -d "$userCacheDir" ]]; then
        # Run as the logged-in user to clear user caches
        sudo -u "$currentUser" rm -rf "${userCacheDir:?}"/* 2>/dev/null
        if [[ $? -eq 0 ]]; then
            logMessage "Successfully cleared user cache for ${currentUser}"
        else
            logMessage "Warning: Some user cache items could not be removed"
            overallSuccess=1
        fi
    else
        logMessage "User cache directory not found for ${currentUser}"
    fi
else
    logMessage "No user logged in, skipping user cache cleanup"
fi

logMessage "System cache cleanup completed"

if [[ $overallSuccess -eq 0 ]]; then
    logMessage "All cache operations completed successfully"
    exit 0
else
    logMessage "Cache cleanup completed with some warnings"
    exit 1
fi
