#!/bin/bash

#purpose: List all installed configuration profiles
#date: January 2026

# Constants
SCRIPT_NAME="auditInstalledProfiles"
LOG_TAG="[${SCRIPT_NAME}]"

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
logMessage "Starting configuration profiles audit..."

# Get system information
hostName=$(hostname)
osVersion=$(/usr/bin/sw_vers -productVersion)
serialNumber=$(/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | awk '{print $4}' | tr -d '"')

logMessage "============================================"
logMessage "Configuration Profiles Audit Report"
logMessage "============================================"
logMessage "Hostname: ${hostName}"
logMessage "Serial Number: ${serialNumber}"
logMessage "macOS Version: ${osVersion}"
logMessage "Audit Date: $(date)"
logMessage "============================================"

# Check if profiles command exists
if [[ ! -x /usr/bin/profiles ]]; then
    logMessage "ERROR: profiles command not found"
    exit 1
fi

# Get all installed profiles
logMessage ""
logMessage "Retrieving installed configuration profiles..."
logMessage ""

# System-level profiles (requires root)
logMessage "=== SYSTEM PROFILES ==="

systemProfiles=$(/usr/bin/profiles -P 2>&1)
systemProfilesExitCode=$?

if [[ ${systemProfilesExitCode} -eq 0 ]]; then
    if [[ -n "${systemProfiles}" ]] && ! echo "${systemProfiles}" | grep -qi "no profiles"; then
        profileCount=0
        currentProfile=""

        # Parse and display profiles
        echo "${systemProfiles}" | while IFS= read -r line; do
            # Check for profile identifier lines
            if [[ "${line}" =~ "attribute:" ]] || [[ "${line}" =~ "profileIdentifier:" ]]; then
                logMessage "  ${line}"
            elif [[ "${line}" =~ ^[[:space:]]*[A-Za-z0-9] ]]; then
                logMessage "${line}"
            fi
        done

        logMessage ""
        logMessage "Raw profiles output:"
        logMessage "${systemProfiles}"
    else
        logMessage "No system-level configuration profiles installed"
    fi
else
    logMessage "WARNING: Could not retrieve system profiles"
    logMessage "Note: System profiles may require root access to view"
fi

logMessage ""

# Get current user for user-level profiles
currentUser=$(getCurrentUser)

if [[ -n "${currentUser}" ]] && [[ "${currentUser}" != "loginwindow" ]]; then
    logMessage "=== USER PROFILES (${currentUser}) ==="

    # User-level profiles
    userProfiles=$(/usr/bin/profiles -L -U "${currentUser}" 2>&1 || echo "")

    if [[ -n "${userProfiles}" ]] && ! echo "${userProfiles}" | grep -qi "no profiles"; then
        logMessage "${userProfiles}"
    else
        logMessage "No user-level configuration profiles for ${currentUser}"
    fi
else
    logMessage "=== USER PROFILES ==="
    logMessage "No user currently logged in"
fi

logMessage ""

# Detailed profile information
logMessage "=== DETAILED PROFILE INFORMATION ==="

# Get detailed profiles in plist format for parsing
detailedOutput=$(/usr/bin/profiles -C -v 2>&1 || echo "")

if [[ -n "${detailedOutput}" ]]; then
    # Count profiles
    profileIdentifiers=$(echo "${detailedOutput}" | grep -c "ProfileIdentifier" || echo "0")
    logMessage "Total profile identifiers found: ${profileIdentifiers}"

    logMessage ""
    logMessage "Profile Details:"

    # Extract and display key profile information
    echo "${detailedOutput}" | grep -E "(ProfileDisplayName|ProfileIdentifier|ProfileInstallDate|ProfileOrganization|ProfileType|ProfileVersion)" | while IFS= read -r line; do
        # Clean up and format the output
        cleanLine=$(echo "${line}" | sed 's/^[[:space:]]*/  /')
        logMessage "${cleanLine}"
    done
fi

logMessage ""

# Check for MDM enrollment
logMessage "=== MDM ENROLLMENT STATUS ==="

mdmProfile=$(/usr/bin/profiles status -type enrollment 2>&1 || echo "")

if [[ -n "${mdmProfile}" ]]; then
    logMessage "${mdmProfile}"

    if echo "${mdmProfile}" | grep -qi "MDM enrollment: Yes"; then
        logMessage "STATUS: Device is enrolled in MDM"

        # Get MDM server info if available
        mdmServer=$(echo "${mdmProfile}" | grep -i "server" || echo "")
        if [[ -n "${mdmServer}" ]]; then
            logMessage "MDM Server: ${mdmServer}"
        fi
    else
        logMessage "STATUS: Device is NOT enrolled in MDM"
    fi
else
    logMessage "Unable to determine MDM enrollment status"
fi

logMessage ""

# Check for DEP/ADE enrollment
logMessage "=== DEP/ADE STATUS ==="

depStatus=$(/usr/bin/profiles show -type enrollment 2>&1 || echo "")

if [[ -n "${depStatus}" ]]; then
    logMessage "${depStatus}"
else
    logMessage "Unable to determine DEP/ADE status"
fi

logMessage ""

# Security-relevant profiles check
logMessage "=== SECURITY PROFILE ANALYSIS ==="

securityProfilesFound=0

# Check for common security-related profile types
securityKeywords="passcode|password|FileVault|firewall|Gatekeeper|privacy|security|restriction|compliance"

if echo "${systemProfiles}" | grep -qiE "${securityKeywords}"; then
    logMessage "Security-related profiles detected:"
    echo "${systemProfiles}" | grep -iE "${securityKeywords}" | while IFS= read -r line; do
        logMessage "  ${line}"
        ((securityProfilesFound++))
    done
else
    logMessage "No security-specific profile keywords detected"
fi

logMessage ""

# Summary
logMessage "============================================"
logMessage "Configuration Profiles Audit Summary"
logMessage "============================================"
logMessage "Audit completed at: $(date)"

# Final profile count
totalProfiles=$(/usr/bin/profiles -P 2>/dev/null | grep -c "profileIdentifier" || echo "0")
logMessage "Total Configuration Profiles: ${totalProfiles}"

logMessage "============================================"

logMessage "Profile audit completed successfully"
exit 0
