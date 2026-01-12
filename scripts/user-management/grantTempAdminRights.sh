#!/bin/bash

#########################################################################################
# Script Name:  grantTempAdminRights.sh
# Purpose:      Grant temporary admin rights for X minutes (Self Service)
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = minutes (optional, default: 30)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
ADMIN_MINUTES="${4:-30}"

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
LAUNCHDAEMON_PATH="/Library/LaunchDaemons/com.company.removeadmin"
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

validateParameters() {
    if ! [[ "${ADMIN_MINUTES}" =~ ^[0-9]+$ ]]; then
        logMessage "ERROR: Minutes must be a positive integer"
        exit 1
    fi

    if [[ "${ADMIN_MINUTES}" -lt 1 ]] || [[ "${ADMIN_MINUTES}" -gt 480 ]]; then
        logMessage "ERROR: Minutes must be between 1 and 480 (8 hours max)"
        exit 1
    fi
}

isUserAdmin() {
    local username="$1"
    if dseditgroup -o checkmember -m "${username}" admin &>/dev/null; then
        return 0
    fi
    return 1
}

grantAdminRights() {
    local username="$1"

    logMessage "Granting admin rights to ${username}"

    if dseditgroup -o edit -a "${username}" -t user admin; then
        logMessage "Successfully granted admin rights to ${username}"
        return 0
    else
        logMessage "ERROR: Failed to grant admin rights to ${username}"
        return 1
    fi
}

removeAdminRights() {
    local username="$1"

    logMessage "Removing admin rights from ${username}"

    if dseditgroup -o edit -d "${username}" -t user admin; then
        logMessage "Successfully removed admin rights from ${username}"
        return 0
    else
        logMessage "ERROR: Failed to remove admin rights from ${username}"
        return 1
    fi
}

createRemovalScript() {
    local username="$1"
    local scriptPath="/usr/local/bin/removeAdminRights_${username}.sh"

    # Create the removal script
    cat > "${scriptPath}" << EOF
#!/bin/bash
# Auto-generated script to remove temporary admin rights

LOG_FILE="/var/log/jamf_user_management.log"
USERNAME="${username}"

logMessage() {
    local message="\$1"
    local timestamp
    timestamp=\$(date "+%Y-%m-%d %H:%M:%S")
    echo "\${timestamp}: \${message}" | tee -a "\${LOG_FILE}"
}

logMessage "Temporary admin period expired for \${USERNAME}"

# Remove from admin group
if dseditgroup -o edit -d "\${USERNAME}" -t user admin 2>/dev/null; then
    logMessage "Successfully removed admin rights from \${USERNAME}"
else
    logMessage "WARNING: Could not remove admin rights from \${USERNAME}"
fi

# Clean up LaunchDaemon
launchctl bootout system "/Library/LaunchDaemons/com.company.removeadmin.${username}.plist" 2>/dev/null
rm -f "/Library/LaunchDaemons/com.company.removeadmin.${username}.plist"
rm -f "/usr/local/bin/removeAdminRights_${username}.sh"

logMessage "Cleanup completed for \${USERNAME}"
EOF

    chmod 755 "${scriptPath}"
    logMessage "Created removal script: ${scriptPath}"
    echo "${scriptPath}"
}

createLaunchDaemon() {
    local username="$1"
    local minutes="$2"
    local scriptPath="$3"
    local plistPath="${LAUNCHDAEMON_PATH}.${username}.plist"
    local runDate

    # Calculate the run date
    runDate=$(date -v "+${minutes}M" "+%Y-%m-%dT%H:%M:%SZ")

    # Create the LaunchDaemon plist
    cat > "${plistPath}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.company.removeadmin.${username}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${scriptPath}</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Minute</key>
        <integer>$(date -v "+${minutes}M" "+%M" | sed 's/^0//')</integer>
        <key>Hour</key>
        <integer>$(date -v "+${minutes}M" "+%H" | sed 's/^0//')</integer>
        <key>Day</key>
        <integer>$(date -v "+${minutes}M" "+%d" | sed 's/^0//')</integer>
        <key>Month</key>
        <integer>$(date -v "+${minutes}M" "+%m" | sed 's/^0//')</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

    # Set proper permissions
    chmod 644 "${plistPath}"
    chown root:wheel "${plistPath}"

    # Load the LaunchDaemon
    launchctl bootstrap system "${plistPath}"

    logMessage "Created LaunchDaemon to remove admin at $(date -v "+${minutes}M")"
}

notifyUser() {
    local username="$1"
    local minutes="$2"
    local userID

    userID=$(id -u "${username}")

    # Send notification to user
    launchctl asuser "${userID}" osascript -e "display notification \"You have been granted temporary admin rights for ${minutes} minutes. Rights will be automatically removed.\" with title \"Temporary Admin Rights\""
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting grantTempAdminRights.sh =========="
logMessage "Duration: ${ADMIN_MINUTES} minutes"

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if we have a valid console user
if [[ -z "${CURRENT_USER}" ]] || [[ "${CURRENT_USER}" == "root" ]] || [[ "${CURRENT_USER}" == "loginwindow" ]]; then
    logMessage "ERROR: No valid user logged in at console"
    exit 1
fi

logMessage "Current user: ${CURRENT_USER}"

# Check if user is already an admin
if isUserAdmin "${CURRENT_USER}"; then
    logMessage "WARNING: User ${CURRENT_USER} is already an admin"
    # Still proceed to ensure rights are removed after the time period
fi

# Grant admin rights
if ! grantAdminRights "${CURRENT_USER}"; then
    exit 1
fi

# Create removal script
removalScript=$(createRemovalScript "${CURRENT_USER}")

# Create LaunchDaemon to remove rights
createLaunchDaemon "${CURRENT_USER}" "${ADMIN_MINUTES}" "${removalScript}"

# Notify the user
notifyUser "${CURRENT_USER}" "${ADMIN_MINUTES}"

logMessage "Admin rights granted to ${CURRENT_USER} for ${ADMIN_MINUTES} minutes"
logMessage "Script completed successfully"
exit 0
