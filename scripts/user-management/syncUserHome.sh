#!/bin/bash

#########################################################################################
# Script Name:  syncUserHome.sh
# Purpose:      Sync user home folder to network location
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = username (required)
#   $5 = destination path (required) - can be local path or SMB/AFP share
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
USERNAME="$4"
DESTINATION_PATH="$5"

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
RSYNC_OPTIONS="-avz --progress --delete --exclude='.Trash' --exclude='Library/Caches' --exclude='.DS_Store' --exclude='*.tmp'"
MOUNT_POINT="/Volumes/UserBackup"

#########################################################################################
# FUNCTIONS
#########################################################################################

logMessage() {
    local message="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${timestamp}: ${message}" | tee -a "${LOG_FILE}"
}

validateParameters() {
    if [[ -z "${USERNAME}" ]]; then
        logMessage "ERROR: Username parameter (\$4) is required"
        exit 1
    fi

    if [[ -z "${DESTINATION_PATH}" ]]; then
        logMessage "ERROR: Destination path parameter (\$5) is required"
        exit 1
    fi
}

checkUserExists() {
    if ! dscl . -read "/Users/${USERNAME}" &>/dev/null; then
        logMessage "ERROR: User '${USERNAME}' does not exist"
        exit 1
    fi
}

getUserHomeDir() {
    local username="$1"
    local homeDir

    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory | awk '{print $2}')

    if [[ ! -d "${homeDir}" ]]; then
        logMessage "ERROR: Home directory not found: ${homeDir}"
        exit 1
    fi

    echo "${homeDir}"
}

isNetworkPath() {
    local path="$1"

    if [[ "${path}" =~ ^smb:// ]] || [[ "${path}" =~ ^afp:// ]] || [[ "${path}" =~ ^nfs:// ]]; then
        return 0
    fi
    return 1
}

mountNetworkShare() {
    local sharePath="$1"
    local mountPoint="$2"

    logMessage "Mounting network share: ${sharePath}"

    # Create mount point if needed
    mkdir -p "${mountPoint}"

    # Mount the share
    if mount_smbfs "${sharePath}" "${mountPoint}" 2>/dev/null; then
        logMessage "Successfully mounted ${sharePath}"
        return 0
    elif mount -t smbfs "${sharePath}" "${mountPoint}" 2>/dev/null; then
        logMessage "Successfully mounted ${sharePath}"
        return 0
    else
        logMessage "ERROR: Failed to mount network share"
        return 1
    fi
}

unmountNetworkShare() {
    local mountPoint="$1"

    if [[ -d "${mountPoint}" ]] && mount | grep -q "${mountPoint}"; then
        logMessage "Unmounting: ${mountPoint}"
        umount "${mountPoint}" 2>/dev/null
        rmdir "${mountPoint}" 2>/dev/null
    fi
}

calculateSyncSize() {
    local sourceDir="$1"
    local sizeBytes
    local sizeHuman

    sizeBytes=$(du -s "${sourceDir}" 2>/dev/null | awk '{print $1}')
    sizeHuman=$(du -sh "${sourceDir}" 2>/dev/null | awk '{print $1}')

    logMessage "Source directory size: ${sizeHuman}"
    echo "${sizeBytes}"
}

checkDestinationSpace() {
    local destination="$1"
    local requiredKB="$2"
    local availableKB

    availableKB=$(df -k "${destination}" 2>/dev/null | tail -1 | awk '{print $4}')

    if [[ -z "${availableKB}" ]]; then
        logMessage "WARNING: Could not determine available space at destination"
        return 0
    fi

    if [[ "${availableKB}" -lt "${requiredKB}" ]]; then
        logMessage "ERROR: Insufficient space at destination (needed: ${requiredKB}KB, available: ${availableKB}KB)"
        return 1
    fi

    logMessage "Destination has sufficient space (available: ${availableKB}KB)"
    return 0
}

syncHomeFolder() {
    local sourceDir="$1"
    local destDir="$2"
    local excludeFile="/tmp/rsync_exclude_${USERNAME}.txt"

    logMessage "Starting sync from ${sourceDir} to ${destDir}"

    # Create exclude file for rsync
    cat > "${excludeFile}" << 'EOF'
.Trash
.Trashes
Library/Caches
Library/Logs
Library/Application Support/MobileSync
*.tmp
*.temp
.DS_Store
.localized
.fseventsd
.Spotlight-V100
.TemporaryItems
EOF

    # Ensure destination directory exists
    mkdir -p "${destDir}"

    # Run rsync with progress logging
    logMessage "Running rsync..."

    if rsync -avz --progress --delete \
        --exclude-from="${excludeFile}" \
        "${sourceDir}/" "${destDir}/" 2>&1 | while read -r line; do
            # Log progress periodically
            if [[ "${line}" =~ "sent" ]] || [[ "${line}" =~ "total size" ]]; then
                logMessage "${line}"
            fi
        done; then
        logMessage "Sync completed successfully"
        rm -f "${excludeFile}"
        return 0
    else
        logMessage "ERROR: Sync failed"
        rm -f "${excludeFile}"
        return 1
    fi
}

createSyncReport() {
    local username="$1"
    local sourceDir="$2"
    local destDir="$3"
    local reportFile="${destDir}/.sync_report.txt"

    {
        echo "User Home Sync Report"
        echo "====================="
        echo "User: ${username}"
        echo "Source: ${sourceDir}"
        echo "Destination: ${destDir}"
        echo "Sync Date: $(date)"
        echo "Sync Host: $(hostname)"
        echo ""
        echo "Source Size: $(du -sh "${sourceDir}" 2>/dev/null | awk '{print $1}')"
        echo "Destination Size: $(du -sh "${destDir}" 2>/dev/null | awk '{print $1}')"
    } > "${reportFile}"

    logMessage "Created sync report: ${reportFile}"
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting syncUserHome.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if user exists
checkUserExists

# Get home directory
homeDir=$(getUserHomeDir "${USERNAME}")
logMessage "Home directory: ${homeDir}"

# Calculate source size
sourceSize=$(calculateSyncSize "${homeDir}")

# Handle network paths
actualDestination="${DESTINATION_PATH}"
networkMounted=false

if isNetworkPath "${DESTINATION_PATH}"; then
    logMessage "Destination is a network path"

    # Extract share path for mounting
    # Convert smb://server/share format to //server/share
    sharePath=$(echo "${DESTINATION_PATH}" | sed 's|smb://|//|' | sed 's|afp://|//|')

    if mountNetworkShare "${sharePath}" "${MOUNT_POINT}"; then
        actualDestination="${MOUNT_POINT}/${USERNAME}"
        networkMounted=true
    else
        logMessage "ERROR: Could not mount network share"
        exit 1
    fi
fi

# Ensure destination exists
if [[ ! -d "${actualDestination}" ]]; then
    logMessage "Creating destination directory: ${actualDestination}"
    mkdir -p "${actualDestination}"
fi

# Check destination space
if ! checkDestinationSpace "${actualDestination}" "${sourceSize}"; then
    if [[ "${networkMounted}" == "true" ]]; then
        unmountNetworkShare "${MOUNT_POINT}"
    fi
    exit 1
fi

# Perform the sync
syncResult=0
if syncHomeFolder "${homeDir}" "${actualDestination}"; then
    createSyncReport "${USERNAME}" "${homeDir}" "${actualDestination}"
else
    syncResult=1
fi

# Cleanup: unmount network share if mounted
if [[ "${networkMounted}" == "true" ]]; then
    unmountNetworkShare "${MOUNT_POINT}"
fi

if [[ "${syncResult}" -eq 0 ]]; then
    logMessage "Script completed successfully"
    echo "Home folder for ${USERNAME} synced to ${DESTINATION_PATH}"
    exit 0
else
    logMessage "Script failed"
    exit 1
fi
