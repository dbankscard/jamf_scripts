#!/bin/bash

#########################################################################################
# Script Name:  migrateADtoLocal.sh
# Purpose:      Migrate Active Directory mobile account to local account
# Date:         January 2026
#
# Jamf Parameters:
#   None (migrates current logged-in user or all mobile accounts)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
CURRENT_USER=$(stat -f "%Su" /dev/console)

#########################################################################################
# FUNCTIONS
#########################################################################################

logMessage() {
    local message="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${timestamp}: ${message}" | tee -a "${LOG_FILE}"
}

isMobileAccount() {
    local username="$1"
    local accountType

    accountType=$(dscl . -read "/Users/${username}" OriginalAuthenticationAuthority 2>/dev/null)

    if [[ -n "${accountType}" ]]; then
        return 0
    fi

    # Also check for cached credentials
    if dscl . -read "/Users/${username}" AuthenticationAuthority 2>/dev/null | grep -q "LocalCachedUser"; then
        return 0
    fi

    return 1
}

backupUserData() {
    local username="$1"
    local homeDir
    local backupDir

    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory | awk '{print $2}')
    backupDir="/var/tmp/${username}_backup_$(date +%Y%m%d%H%M%S)"

    logMessage "Backing up user data for ${username}"

    # Create backup of important user attributes
    mkdir -p "${backupDir}"
    dscl . -read "/Users/${username}" > "${backupDir}/user_record.txt"

    echo "${backupDir}"
}

migrateAccount() {
    local username="$1"
    local userUID
    local userGID
    local homeDir
    local realName
    local userShell
    local originalNodeName

    logMessage "Starting migration for user: ${username}"

    # Get current user attributes
    userUID=$(dscl . -read "/Users/${username}" UniqueID | awk '{print $2}')
    userGID=$(dscl . -read "/Users/${username}" PrimaryGroupID | awk '{print $2}')
    homeDir=$(dscl . -read "/Users/${username}" NFSHomeDirectory | awk '{print $2}')
    realName=$(dscl . -read "/Users/${username}" RealName | sed -n 's/^RealName: //p')
    userShell=$(dscl . -read "/Users/${username}" UserShell | awk '{print $2}')

    if [[ -z "${realName}" ]]; then
        realName="${username}"
    fi

    # Backup user data
    backupUserData "${username}"

    # Remove AD-related attributes
    logMessage "Removing AD authentication attributes for ${username}"

    # Remove OriginalAuthenticationAuthority
    dscl . -delete "/Users/${username}" OriginalAuthenticationAuthority 2>/dev/null

    # Remove cached user AuthenticationAuthority and replace with local
    dscl . -delete "/Users/${username}" AuthenticationAuthority 2>/dev/null

    # Remove OriginalNodeName if present
    dscl . -delete "/Users/${username}" OriginalNodeName 2>/dev/null

    # Remove LKDC attributes
    dscl . -delete "/Users/${username}" AltSecurityIdentities 2>/dev/null

    # Remove SMB attributes that may be present
    dscl . -delete "/Users/${username}" SMBGroupRID 2>/dev/null
    dscl . -delete "/Users/${username}" SMBHome 2>/dev/null
    dscl . -delete "/Users/${username}" SMBHomeDrive 2>/dev/null
    dscl . -delete "/Users/${username}" SMBPasswordLastSet 2>/dev/null
    dscl . -delete "/Users/${username}" SMBPrimaryGroupSID 2>/dev/null
    dscl . -delete "/Users/${username}" SMBSID 2>/dev/null

    # Remove CopyTimestamp
    dscl . -delete "/Users/${username}" CopyTimestamp 2>/dev/null

    # Create new local password hash
    logMessage "Account ${username} migrated to local. User will need to set a new password."

    # Check if user is admin and preserve that
    if dseditgroup -o checkmember -m "${username}" admin &>/dev/null; then
        logMessage "User ${username} is an admin - preserving admin status"
    fi

    # Fix home directory ownership
    if [[ -d "${homeDir}" ]]; then
        logMessage "Fixing home directory ownership for ${username}"
        chown -R "${userUID}:${userGID}" "${homeDir}"
    fi

    logMessage "Migration completed for ${username}"
    return 0
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting migrateADtoLocal.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Find all mobile accounts
migratedCount=0
errorCount=0

# Check current console user first
if [[ -n "${CURRENT_USER}" ]] && [[ "${CURRENT_USER}" != "root" ]] && [[ "${CURRENT_USER}" != "loginwindow" ]]; then
    if isMobileAccount "${CURRENT_USER}"; then
        logMessage "Current user ${CURRENT_USER} is a mobile account"
        if migrateAccount "${CURRENT_USER}"; then
            ((migratedCount++))
        else
            ((errorCount++))
        fi
    else
        logMessage "Current user ${CURRENT_USER} is not a mobile account"
    fi
fi

# Check all other users with UID > 500
while IFS= read -r username; do
    # Skip current user (already processed) and system accounts
    if [[ "${username}" == "${CURRENT_USER}" ]]; then
        continue
    fi

    userUID=$(dscl . -read "/Users/${username}" UniqueID 2>/dev/null | awk '{print $2}')
    if [[ -z "${userUID}" ]] || [[ "${userUID}" -lt 500 ]]; then
        continue
    fi

    if isMobileAccount "${username}"; then
        logMessage "Found mobile account: ${username}"
        if migrateAccount "${username}"; then
            ((migratedCount++))
        else
            ((errorCount++))
        fi
    fi
done < <(dscl . -list /Users | grep -v "^_")

logMessage "Migrated ${migratedCount} mobile accounts to local accounts"

if [[ "${errorCount}" -gt 0 ]]; then
    logMessage "WARNING: ${errorCount} accounts failed to migrate"
    exit 1
fi

if [[ "${migratedCount}" -eq 0 ]]; then
    logMessage "No mobile accounts found to migrate"
fi

logMessage "Script completed successfully"
exit 0
