#!/bin/bash

#purpose: Verify screen lock timeout is set (IdleTime)
#date: January 2026

# Constants
SCRIPT_NAME="checkScreenLock"
LOG_TAG="[${SCRIPT_NAME}]"

# Compliance thresholds (in seconds)
MAX_IDLE_TIME=900  # 15 minutes maximum recommended
MAX_PASSWORD_DELAY=5  # 5 seconds maximum delay before password required

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

getCurrentUser() {
    local currentUser
    currentUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')
    echo "${currentUser}"
}

secondsToMinutes() {
    local seconds="$1"
    local minutes=$((seconds / 60))
    echo "${minutes}"
}

# Main script
logMessage "Starting screen lock settings check..."

# Get current console user
currentUser=$(getCurrentUser)

if [[ -z "${currentUser}" ]] || [[ "${currentUser}" == "loginwindow" ]] || [[ "${currentUser}" == "root" ]]; then
    logMessage "WARNING: No user currently logged in"
    logMessage "Cannot check user-specific screen lock settings"
    logMessage "STATUS: UNABLE TO CHECK - No user session"
    exit 0
fi

logMessage "Current user: ${currentUser}"
currentUserHome=$(/usr/bin/dscl . -read "/Users/${currentUser}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
logMessage "User home directory: ${currentUserHome}"

# Initialize compliance tracking
complianceIssues=0

# Check screen saver idle time
logMessage "Checking screen saver idle time..."

idleTime=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo "not set")

if [[ "${idleTime}" == "not set" ]] || [[ -z "${idleTime}" ]]; then
    logMessage "Screen Saver Idle Time: NOT CONFIGURED"
    logMessage "WARNING: No screen saver idle time is set"
    ((complianceIssues++))
elif [[ "${idleTime}" =~ ^[0-9]+$ ]]; then
    idleMinutes=$(secondsToMinutes "${idleTime}")
    logMessage "Screen Saver Idle Time: ${idleTime} seconds (${idleMinutes} minutes)"

    if [[ ${idleTime} -eq 0 ]]; then
        logMessage "WARNING: Screen saver is disabled (idle time = 0)"
        ((complianceIssues++))
    elif [[ ${idleTime} -gt ${MAX_IDLE_TIME} ]]; then
        maxMinutes=$(secondsToMinutes "${MAX_IDLE_TIME}")
        logMessage "WARNING: Idle time (${idleMinutes} min) exceeds recommended maximum (${maxMinutes} min)"
        ((complianceIssues++))
    else
        logMessage "PASS: Idle time is within acceptable range"
    fi
else
    logMessage "Screen Saver Idle Time: ${idleTime} (unexpected format)"
fi

# Check if password is required after screen saver
logMessage "Checking password requirement after screen saver..."

askForPassword=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "not set")

if [[ "${askForPassword}" == "1" ]]; then
    logMessage "Password Required After Screen Saver: YES"
    logMessage "PASS: Password is required to unlock"
elif [[ "${askForPassword}" == "0" ]]; then
    logMessage "Password Required After Screen Saver: NO"
    logMessage "FAIL: Password should be required to unlock screen"
    ((complianceIssues++))
else
    logMessage "Password Required After Screen Saver: NOT CONFIGURED (${askForPassword})"
    logMessage "WARNING: Password requirement may not be set"
    ((complianceIssues++))
fi

# Check password delay (grace period)
logMessage "Checking password delay (grace period)..."

askForPasswordDelay=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "not set")

if [[ "${askForPasswordDelay}" =~ ^[0-9]+$ ]]; then
    logMessage "Password Delay: ${askForPasswordDelay} seconds"

    if [[ ${askForPasswordDelay} -gt ${MAX_PASSWORD_DELAY} ]]; then
        logMessage "WARNING: Password delay (${askForPasswordDelay}s) exceeds recommended (${MAX_PASSWORD_DELAY}s)"
        ((complianceIssues++))
    else
        logMessage "PASS: Password delay is acceptable"
    fi
elif [[ "${askForPasswordDelay}" == "not set" ]]; then
    logMessage "Password Delay: NOT CONFIGURED"
    logMessage "NOTE: Default behavior may apply"
else
    logMessage "Password Delay: ${askForPasswordDelay} (unexpected format)"
fi

# Check for hot corners that might activate screen saver
logMessage "Checking hot corners configuration..."

# Hot corners are stored in com.apple.dock
# Corner values: 0=disabled, 5=start screen saver, 6=disable screen saver
for corner in "wvous-tl-corner" "wvous-tr-corner" "wvous-bl-corner" "wvous-br-corner"; do
    cornerValue=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults read com.apple.dock "${corner}" 2>/dev/null || echo "not set")
    if [[ "${cornerValue}" == "5" ]]; then
        cornerName=$(echo "${corner}" | sed 's/wvous-//' | sed 's/-corner//' | tr 'a-z' 'A-Z')
        logMessage "Hot Corner (${cornerName}): Start Screen Saver"
    fi
done

# Check display sleep settings (system level)
logMessage "Checking display sleep settings..."

displaySleep=$(/usr/bin/pmset -g custom 2>/dev/null | grep "displaysleep" | head -1 | awk '{print $2}')

if [[ -n "${displaySleep}" ]] && [[ "${displaySleep}" =~ ^[0-9]+$ ]]; then
    logMessage "Display Sleep (Battery/AC): ${displaySleep} minutes"
    displaySleepSeconds=$((displaySleep * 60))

    if [[ ${displaySleep} -eq 0 ]]; then
        logMessage "WARNING: Display sleep is disabled"
        ((complianceIssues++))
    elif [[ ${displaySleepSeconds} -gt ${MAX_IDLE_TIME} ]]; then
        maxMinutes=$(secondsToMinutes "${MAX_IDLE_TIME}")
        logMessage "WARNING: Display sleep (${displaySleep} min) exceeds recommended maximum (${maxMinutes} min)"
    fi
fi

# Check for lock on sleep
logMessage "Checking require password on wake..."

# This is typically enforced via MDM or security profile
# Check the global preference
requirePasswordOnWake=$(/usr/bin/defaults read com.apple.loginwindow DisableScreenLockImmediate 2>/dev/null || echo "not found")

if [[ "${requirePasswordOnWake}" == "0" ]] || [[ "${requirePasswordOnWake}" == "not found" ]]; then
    logMessage "Immediate Screen Lock: ENABLED (or default)"
else
    logMessage "WARNING: Immediate screen lock may be disabled"
    ((complianceIssues++))
fi

# Summary
logMessage "============================================"
logMessage "Screen Lock Settings Summary"
logMessage "============================================"
logMessage "User: ${currentUser}"
logMessage "Idle Time: ${idleTime} seconds"
logMessage "Password Required: ${askForPassword}"
logMessage "Password Delay: ${askForPasswordDelay} seconds"
logMessage "Compliance Issues: ${complianceIssues}"
logMessage "============================================"

if [[ ${complianceIssues} -eq 0 ]]; then
    logMessage "STATUS: COMPLIANT - Screen lock settings meet requirements"
    exit 0
else
    logMessage "STATUS: NON-COMPLIANT - ${complianceIssues} issue(s) found"
    exit 1
fi
