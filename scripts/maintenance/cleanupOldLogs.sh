#!/bin/bash

#purpose: Remove old logs from /var/log and ~/Library/Logs older than 30 days
#date: January 2026

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly SYSTEM_LOG_DIR="/var/log"
readonly MAX_AGE_DAYS=30

# Get the currently logged-in user
currentUser=$(stat -f "%Su" /dev/console)
userHome=$(dscl . -read /Users/"$currentUser" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
userLogDir="${userHome}/Library/Logs"

# Function to log messages
logMessage() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${SCRIPT_NAME}: ${message}"
}

# Function to cleanup old logs in a directory
cleanupLogs() {
    local logDir="$1"
    local description="$2"
    local runAsUser="$3"

    if [[ ! -d "$logDir" ]]; then
        logMessage "Warning: ${description} directory not found at ${logDir}"
        return 1
    fi

    logMessage "Cleaning up ${description} at ${logDir}..."

    # Count files before cleanup
    local beforeCount
    if [[ -n "$runAsUser" ]]; then
        beforeCount=$(sudo -u "$runAsUser" find "$logDir" -type f -mtime +${MAX_AGE_DAYS} 2>/dev/null | wc -l | tr -d ' ')
    else
        beforeCount=$(find "$logDir" -type f -mtime +${MAX_AGE_DAYS} 2>/dev/null | wc -l | tr -d ' ')
    fi

    logMessage "Found ${beforeCount} log file(s) older than ${MAX_AGE_DAYS} days"

    if [[ "$beforeCount" -eq 0 ]]; then
        logMessage "No old log files to remove in ${description}"
        return 0
    fi

    # Remove old log files
    local removedCount=0
    local errorCount=0

    if [[ -n "$runAsUser" ]]; then
        # Run as specified user
        while IFS= read -r file; do
            if sudo -u "$runAsUser" rm -f "$file" 2>/dev/null; then
                ((removedCount++))
            else
                ((errorCount++))
            fi
        done < <(sudo -u "$runAsUser" find "$logDir" -type f -mtime +${MAX_AGE_DAYS} 2>/dev/null)
    else
        # Run as root
        while IFS= read -r file; do
            if rm -f "$file" 2>/dev/null; then
                ((removedCount++))
            else
                ((errorCount++))
            fi
        done < <(find "$logDir" -type f -mtime +${MAX_AGE_DAYS} 2>/dev/null)
    fi

    logMessage "Removed ${removedCount} log file(s) from ${description}"

    if [[ $errorCount -gt 0 ]]; then
        logMessage "Warning: ${errorCount} file(s) could not be removed (may be in use or protected)"
    fi

    # Also remove empty directories
    if [[ -n "$runAsUser" ]]; then
        sudo -u "$runAsUser" find "$logDir" -type d -empty -delete 2>/dev/null
    else
        find "$logDir" -type d -empty -delete 2>/dev/null
    fi

    return 0
}

# Function to calculate space freed
getDirectorySize() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sh "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Main execution
logMessage "Starting log cleanup..."
logMessage "Removing log files older than ${MAX_AGE_DAYS} days"

# Track overall success
overallSuccess=0
totalSystemRemoved=0
totalUserRemoved=0

# Get initial sizes
systemSizeBefore=$(getDirectorySize "$SYSTEM_LOG_DIR")

# Cleanup system logs
cleanupLogs "$SYSTEM_LOG_DIR" "system logs" ""
[[ $? -ne 0 ]] && overallSuccess=1

systemSizeAfter=$(getDirectorySize "$SYSTEM_LOG_DIR")
logMessage "System logs: ${systemSizeBefore} -> ${systemSizeAfter}"

# Cleanup user logs if a user is logged in
if [[ "$currentUser" != "root" ]] && [[ "$currentUser" != "loginwindow" ]] && [[ -n "$currentUser" ]]; then
    logMessage "Current user: ${currentUser}"

    if [[ -d "$userLogDir" ]]; then
        userSizeBefore=$(getDirectorySize "$userLogDir")

        cleanupLogs "$userLogDir" "user logs" "$currentUser"
        [[ $? -ne 0 ]] && overallSuccess=1

        userSizeAfter=$(getDirectorySize "$userLogDir")
        logMessage "User logs: ${userSizeBefore} -> ${userSizeAfter}"
    else
        logMessage "User log directory not found for ${currentUser}"
    fi
else
    logMessage "No user logged in, skipping user log cleanup"
fi

# Also clean up some common system log locations
additionalLogDirs=(
    "/Library/Logs"
    "/var/log/asl"
)

for logDir in "${additionalLogDirs[@]}"; do
    if [[ -d "$logDir" ]]; then
        cleanupLogs "$logDir" "logs in ${logDir}" ""
    fi
done

logMessage "Log cleanup completed"

if [[ $overallSuccess -eq 0 ]]; then
    logMessage "All log cleanup operations completed successfully"
    exit 0
else
    logMessage "Log cleanup completed with some warnings"
    exit 1
fi
