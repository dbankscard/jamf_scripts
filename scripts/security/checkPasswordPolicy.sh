#!/bin/bash

#purpose: Check password policy settings (length, complexity, age)
#date: January 2026

# Constants
SCRIPT_NAME="checkPasswordPolicy"
LOG_TAG="[${SCRIPT_NAME}]"

# Compliance thresholds (adjust as needed)
MIN_PASSWORD_LENGTH=8
MAX_PASSWORD_AGE_DAYS=90
MIN_COMPLEX_CHARS=1

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

# Main script
logMessage "Starting password policy check..."

# Get macOS version
osVersion=$(/usr/bin/sw_vers -productVersion)
majorVersion=$(echo "${osVersion}" | cut -d. -f1)

logMessage "macOS Version: ${osVersion}"

# Initialize compliance tracking
policyFound=false
complianceIssues=0

# Check for configuration profiles with password policies
logMessage "Checking for password policy configuration profiles..."

profilesList=$(/usr/bin/profiles -P 2>/dev/null || true)

if [[ -n "${profilesList}" ]]; then
    logMessage "Configuration profiles found"

    # Look for password policy related profiles
    if echo "${profilesList}" | grep -qi "password\|passcode"; then
        logMessage "Password-related configuration profiles detected"
        policyFound=true
    fi
fi

# Check pwpolicy settings
logMessage "Checking pwpolicy settings..."

# Get global password policy
globalPolicy=$(/usr/bin/pwpolicy -getglobalpolicy 2>/dev/null || echo "")

if [[ -n "${globalPolicy}" ]] && [[ "${globalPolicy}" != *"Error"* ]]; then
    logMessage "Global Password Policy:"
    echo "${globalPolicy}" | while read -r line; do
        logMessage "  ${line}"
    done
    policyFound=true

    # Parse specific policy settings
    # Check minimum length
    minLength=$(echo "${globalPolicy}" | grep -i "minChars" | sed 's/.*minChars=\([0-9]*\).*/\1/' || echo "0")
    if [[ -n "${minLength}" ]] && [[ "${minLength}" =~ ^[0-9]+$ ]]; then
        logMessage "Minimum Password Length: ${minLength}"
        if [[ ${minLength} -lt ${MIN_PASSWORD_LENGTH} ]]; then
            logMessage "WARNING: Minimum length (${minLength}) is below recommended (${MIN_PASSWORD_LENGTH})"
            ((complianceIssues++))
        else
            logMessage "PASS: Minimum length meets requirements"
        fi
    fi

    # Check password age/expiration
    maxAge=$(echo "${globalPolicy}" | grep -i "maxMinutesUntilChangePassword" | sed 's/.*maxMinutesUntilChangePassword=\([0-9]*\).*/\1/' || echo "0")
    if [[ -n "${maxAge}" ]] && [[ "${maxAge}" =~ ^[0-9]+$ ]] && [[ ${maxAge} -gt 0 ]]; then
        maxAgeDays=$((maxAge / 1440))
        logMessage "Maximum Password Age: ${maxAgeDays} days"
        if [[ ${maxAgeDays} -gt ${MAX_PASSWORD_AGE_DAYS} ]]; then
            logMessage "WARNING: Password age (${maxAgeDays} days) exceeds recommended (${MAX_PASSWORD_AGE_DAYS} days)"
            ((complianceIssues++))
        else
            logMessage "PASS: Password age meets requirements"
        fi
    else
        logMessage "NOTE: No password expiration policy set"
    fi

    # Check complexity requirements
    requiresAlpha=$(echo "${globalPolicy}" | grep -i "requiresAlpha" || echo "")
    requiresNumeric=$(echo "${globalPolicy}" | grep -i "requiresNumeric" || echo "")
    requiresSymbol=$(echo "${globalPolicy}" | grep -i "requiresSymbol" || echo "")

    logMessage "Complexity Requirements:"
    if [[ -n "${requiresAlpha}" ]]; then
        logMessage "  Requires alphabetic characters: Yes"
    fi
    if [[ -n "${requiresNumeric}" ]]; then
        logMessage "  Requires numeric characters: Yes"
    fi
    if [[ -n "${requiresSymbol}" ]]; then
        logMessage "  Requires symbols: Yes"
    fi

else
    logMessage "No global password policy found via pwpolicy"
fi

# Check for MDM-deployed password policies
logMessage "Checking for MDM password policies..."

# Look for screensaver password requirement
currentUser=$(getCurrentUser)

if [[ -n "${currentUser}" ]] && [[ "${currentUser}" != "loginwindow" ]]; then
    # Check askForPassword setting
    askForPassword=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "not set")
    askForPasswordDelay=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "not set")

    logMessage "Screen Saver Password Settings (User: ${currentUser}):"
    logMessage "  Require password: ${askForPassword}"
    logMessage "  Password delay (seconds): ${askForPasswordDelay}"

    if [[ "${askForPassword}" != "1" ]]; then
        logMessage "WARNING: Password not required after screen saver"
        ((complianceIssues++))
    fi
fi

# Check for password hints
passwordHints=$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow RetriesUntilHint 2>/dev/null || echo "not set")
logMessage "Login window password hint retries: ${passwordHints}"

# Check for guest account
guestEnabled=$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "not set")
logMessage "Guest account enabled: ${guestEnabled}"

if [[ "${guestEnabled}" == "1" ]]; then
    logMessage "WARNING: Guest account is enabled"
    ((complianceIssues++))
fi

# Summary
logMessage "============================================"
logMessage "Password Policy Check Summary"
logMessage "============================================"

if [[ "${policyFound}" == "true" ]]; then
    logMessage "Password Policy: CONFIGURED"
else
    logMessage "Password Policy: NOT FOUND or DEFAULT"
    logMessage "NOTE: Consider implementing a password policy via MDM/Configuration Profile"
fi

logMessage "Compliance Issues Found: ${complianceIssues}"

if [[ ${complianceIssues} -eq 0 ]]; then
    logMessage "STATUS: COMPLIANT"
    exit 0
else
    logMessage "STATUS: NON-COMPLIANT (${complianceIssues} issues)"
    exit 1
fi
