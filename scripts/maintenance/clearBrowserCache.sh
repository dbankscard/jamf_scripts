#!/bin/bash

#purpose: Clear Safari, Chrome, and Firefox caches for the logged-in user
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")

# Get the currently logged-in user
currentUser=$(stat -f "%Su" /dev/console)
userHome=$(dscl . -read /Users/"$currentUser" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to clear directory contents safely
clearDirectory() {
    local directory="$1"
    local description="$2"

    if [[ -d "$directory" ]]; then
        sudo -u "$currentUser" rm -rf "${directory:?}"/* 2>/dev/null
        if [[ $? -eq 0 ]]; then
            logMessage "Cleared ${description}"
            return 0
        else
            logMessage "Warning: Could not fully clear ${description}"
            return 1
        fi
    else
        logMessage "Skipping ${description} - directory not found"
        return 0
    fi
}

# Function to clear Safari cache
clearSafariCache() {
    logMessage "Clearing Safari cache..."
    local safariSuccess=0

    # Safari cache locations
    clearDirectory "${userHome}/Library/Caches/com.apple.Safari" "Safari cache"
    [[ $? -ne 0 ]] && safariSuccess=1

    clearDirectory "${userHome}/Library/Caches/com.apple.Safari.SafeBrowsing" "Safari Safe Browsing cache"
    [[ $? -ne 0 ]] && safariSuccess=1

    # Safari webpage previews
    clearDirectory "${userHome}/Library/Caches/com.apple.Safari/Webpage Previews" "Safari webpage previews"

    # Safari favicon cache
    if [[ -f "${userHome}/Library/Safari/Favicon Cache/favicons.db" ]]; then
        sudo -u "$currentUser" rm -f "${userHome}/Library/Safari/Favicon Cache/favicons.db" 2>/dev/null
    fi

    return $safariSuccess
}

# Function to clear Chrome cache
clearChromeCache() {
    logMessage "Clearing Google Chrome cache..."
    local chromeSuccess=0

    # Check if Chrome is installed
    local chromeSupport="${userHome}/Library/Application Support/Google/Chrome"

    if [[ ! -d "$chromeSupport" ]]; then
        logMessage "Google Chrome not found for user ${currentUser}"
        return 0
    fi

    # Chrome cache locations (for default and all profiles)
    for profile in "${chromeSupport}"/*/; do
        if [[ -d "${profile}Cache" ]]; then
            clearDirectory "${profile}Cache" "Chrome cache ($(basename "$profile"))"
            [[ $? -ne 0 ]] && chromeSuccess=1
        fi

        if [[ -d "${profile}Code Cache" ]]; then
            clearDirectory "${profile}Code Cache" "Chrome code cache ($(basename "$profile"))"
            [[ $? -ne 0 ]] && chromeSuccess=1
        fi

        if [[ -d "${profile}GPUCache" ]]; then
            clearDirectory "${profile}GPUCache" "Chrome GPU cache ($(basename "$profile"))"
        fi
    done

    # Chrome application cache
    clearDirectory "${userHome}/Library/Caches/Google/Chrome" "Chrome application cache"
    [[ $? -ne 0 ]] && chromeSuccess=1

    return $chromeSuccess
}

# Function to clear Firefox cache
clearFirefoxCache() {
    logMessage "Clearing Mozilla Firefox cache..."
    local firefoxSuccess=0

    # Check if Firefox is installed
    local firefoxProfiles="${userHome}/Library/Application Support/Firefox/Profiles"

    if [[ ! -d "$firefoxProfiles" ]]; then
        logMessage "Mozilla Firefox not found for user ${currentUser}"
        return 0
    fi

    # Firefox cache locations (for all profiles)
    for profile in "${firefoxProfiles}"/*.*/; do
        if [[ -d "${profile}cache2" ]]; then
            clearDirectory "${profile}cache2" "Firefox cache ($(basename "$profile"))"
            [[ $? -ne 0 ]] && firefoxSuccess=1
        fi

        if [[ -d "${profile}startupCache" ]]; then
            clearDirectory "${profile}startupCache" "Firefox startup cache ($(basename "$profile"))"
        fi
    done

    # Firefox application cache
    clearDirectory "${userHome}/Library/Caches/Firefox" "Firefox application cache"
    clearDirectory "${userHome}/Library/Caches/org.mozilla.firefox" "Firefox org cache"

    return $firefoxSuccess
}

# Main execution
logMessage "Starting browser cache cleanup..."

# Verify a user is logged in
if [[ "$currentUser" == "root" ]] || [[ "$currentUser" == "loginwindow" ]] || [[ -z "$currentUser" ]]; then
    logMessage "Error: No user is currently logged in"
    exit 1
fi

if [[ -z "$userHome" ]] || [[ ! -d "$userHome" ]]; then
    logMessage "Error: Could not determine home directory for user ${currentUser}"
    exit 1
fi

logMessage "Current user: ${currentUser}"
logMessage "Home directory: ${userHome}"

# Track overall success
overallSuccess=0

# Clear Safari cache
clearSafariCache
[[ $? -ne 0 ]] && overallSuccess=1

# Clear Chrome cache
clearChromeCache
[[ $? -ne 0 ]] && overallSuccess=1

# Clear Firefox cache
clearFirefoxCache
[[ $? -ne 0 ]] && overallSuccess=1

logMessage "Browser cache cleanup completed"

if [[ $overallSuccess -eq 0 ]]; then
    logMessage "All browser cache operations completed successfully"
    exit 0
else
    logMessage "Browser cache cleanup completed with some warnings"
    exit 1
fi
