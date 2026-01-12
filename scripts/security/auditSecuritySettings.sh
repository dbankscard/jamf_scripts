#!/bin/bash

#purpose: Comprehensive security audit checking: FileVault, Gatekeeper, Firewall, SIP, auto-login disabled, remote login disabled
#date: January 2026

# Constants
SCRIPT_NAME="auditSecuritySettings"
LOG_TAG="[${SCRIPT_NAME}]"
FIREWALL_CMD="/usr/libexec/ApplicationFirewall/socketfilterfw"

# Variables for tracking compliance
totalChecks=0
passedChecks=0
failedChecks=0
warningChecks=0

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

logResult() {
    local checkName="$1"
    local status="$2"
    local details="$3"

    ((totalChecks++))

    case "${status}" in
        "PASS")
            ((passedChecks++))
            logMessage "[PASS] ${checkName}: ${details}"
            ;;
        "FAIL")
            ((failedChecks++))
            logMessage "[FAIL] ${checkName}: ${details}"
            ;;
        "WARN")
            ((warningChecks++))
            logMessage "[WARN] ${checkName}: ${details}"
            ;;
        *)
            logMessage "[????] ${checkName}: ${details}"
            ;;
    esac
}

checkFileVault() {
    logMessage "Checking FileVault status..."

    if [[ ! -x /usr/bin/fdesetup ]]; then
        logResult "FileVault" "FAIL" "fdesetup command not found"
        return
    fi

    fileVaultStatus=$(/usr/bin/fdesetup status 2>&1)

    if echo "${fileVaultStatus}" | grep -q "FileVault is On"; then
        logResult "FileVault" "PASS" "FileVault is enabled"
    else
        logResult "FileVault" "FAIL" "FileVault is not enabled"
    fi
}

checkGatekeeper() {
    logMessage "Checking Gatekeeper status..."

    if [[ ! -x /usr/sbin/spctl ]]; then
        logResult "Gatekeeper" "FAIL" "spctl command not found"
        return
    fi

    gatekeeperStatus=$(/usr/sbin/spctl --status 2>&1)

    if echo "${gatekeeperStatus}" | grep -q "assessments enabled"; then
        logResult "Gatekeeper" "PASS" "Gatekeeper is enabled"
    else
        logResult "Gatekeeper" "FAIL" "Gatekeeper is disabled"
    fi
}

checkFirewall() {
    logMessage "Checking Application Firewall status..."

    if [[ ! -x "${FIREWALL_CMD}" ]]; then
        logResult "Firewall" "FAIL" "Firewall command not found"
        return
    fi

    firewallStatus=$(${FIREWALL_CMD} --getglobalstate 2>&1)

    if echo "${firewallStatus}" | grep -qi "enabled"; then
        # Check stealth mode
        stealthStatus=$(${FIREWALL_CMD} --getstealthmode 2>&1)
        if echo "${stealthStatus}" | grep -qi "enabled"; then
            logResult "Firewall" "PASS" "Firewall enabled with stealth mode"
        else
            logResult "Firewall" "WARN" "Firewall enabled but stealth mode is disabled"
        fi
    else
        logResult "Firewall" "FAIL" "Firewall is disabled"
    fi
}

checkSIP() {
    logMessage "Checking System Integrity Protection status..."

    if [[ ! -x /usr/bin/csrutil ]]; then
        logResult "SIP" "FAIL" "csrutil command not found"
        return
    fi

    sipStatus=$(/usr/bin/csrutil status 2>&1)

    if echo "${sipStatus}" | grep -q "enabled"; then
        logResult "SIP" "PASS" "System Integrity Protection is enabled"
    else
        logResult "SIP" "FAIL" "System Integrity Protection is disabled"
    fi
}

checkAutoLogin() {
    logMessage "Checking auto-login status..."

    autoLoginUser=$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "")

    if [[ -z "${autoLoginUser}" ]]; then
        logResult "Auto-Login" "PASS" "Auto-login is disabled"
    else
        logResult "Auto-Login" "FAIL" "Auto-login is enabled for user: ${autoLoginUser}"
    fi
}

checkRemoteLogin() {
    logMessage "Checking Remote Login (SSH) status..."

    # Check using systemsetup
    remoteLoginStatus=$(/usr/sbin/systemsetup -getremotelogin 2>&1 || true)

    if echo "${remoteLoginStatus}" | grep -qi "off"; then
        logResult "Remote Login" "PASS" "Remote Login (SSH) is disabled"
    elif echo "${remoteLoginStatus}" | grep -qi "on"; then
        logResult "Remote Login" "FAIL" "Remote Login (SSH) is enabled"
    else
        # Alternative check using launchctl
        sshStatus=$(/bin/launchctl list 2>/dev/null | grep -c "com.openssh.sshd" || echo "0")
        if [[ "${sshStatus}" -eq 0 ]]; then
            logResult "Remote Login" "PASS" "Remote Login (SSH) appears disabled"
        else
            logResult "Remote Login" "WARN" "Remote Login (SSH) status unclear"
        fi
    fi
}

checkSecureBoot() {
    logMessage "Checking Secure Boot status..."

    # Check if this is Apple Silicon
    cpuBrand=$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")

    if echo "${cpuBrand}" | grep -qi "Apple"; then
        # Apple Silicon - check boot policy
        bootPolicy=$(/usr/sbin/bputil -d 2>&1 || echo "")
        if echo "${bootPolicy}" | grep -qi "Full Security"; then
            logResult "Secure Boot" "PASS" "Full Security mode enabled (Apple Silicon)"
        elif echo "${bootPolicy}" | grep -qi "Reduced Security"; then
            logResult "Secure Boot" "WARN" "Reduced Security mode (Apple Silicon)"
        else
            logResult "Secure Boot" "WARN" "Unable to determine Secure Boot status"
        fi
    else
        # Intel Mac - check secure boot if T2 chip present
        t2Check=$(/usr/sbin/ioreg -l | grep -c "AppleT2Controller" || echo "0")
        if [[ "${t2Check}" -gt 0 ]]; then
            logResult "Secure Boot" "PASS" "T2 chip present (Secure Boot available)"
        else
            logResult "Secure Boot" "WARN" "No T2 chip - Secure Boot not available on this Intel Mac"
        fi
    fi
}

checkScreenLock() {
    logMessage "Checking screen lock settings..."

    # Get current user
    currentUser=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ && ! /loginwindow/ { print $3 }')

    if [[ -z "${currentUser}" ]] || [[ "${currentUser}" == "loginwindow" ]]; then
        logResult "Screen Lock" "WARN" "No user logged in to check screen lock settings"
        return
    fi

    # Check screen saver idle time
    idleTime=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo "0")

    # Check if password required after sleep/screen saver
    askForPassword=$(/usr/bin/sudo -u "${currentUser}" /usr/bin/defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "0")

    if [[ "${askForPassword}" -eq 1 ]]; then
        if [[ "${idleTime}" -gt 0 ]] && [[ "${idleTime}" -le 900 ]]; then
            logResult "Screen Lock" "PASS" "Screen lock enabled (idle time: ${idleTime} seconds)"
        elif [[ "${idleTime}" -gt 900 ]]; then
            logResult "Screen Lock" "WARN" "Screen lock idle time is greater than 15 minutes (${idleTime} seconds)"
        else
            logResult "Screen Lock" "WARN" "Screen saver idle time may not be configured"
        fi
    else
        logResult "Screen Lock" "FAIL" "Password not required after screen saver/sleep"
    fi
}

printSummary() {
    logMessage "============================================"
    logMessage "          SECURITY AUDIT SUMMARY            "
    logMessage "============================================"
    logMessage "Total Checks:   ${totalChecks}"
    logMessage "Passed:         ${passedChecks}"
    logMessage "Failed:         ${failedChecks}"
    logMessage "Warnings:       ${warningChecks}"
    logMessage "============================================"

    if [[ ${failedChecks} -eq 0 ]]; then
        if [[ ${warningChecks} -eq 0 ]]; then
            logMessage "OVERALL STATUS: FULLY COMPLIANT"
        else
            logMessage "OVERALL STATUS: COMPLIANT WITH WARNINGS"
        fi
    else
        logMessage "OVERALL STATUS: NON-COMPLIANT"
    fi

    logMessage "============================================"
}

# Main script
logMessage "============================================"
logMessage "  Starting Comprehensive Security Audit     "
logMessage "============================================"
logMessage "Date: $(date)"
logMessage "Hostname: $(hostname)"
logMessage "macOS Version: $(/usr/bin/sw_vers -productVersion)"
logMessage "============================================"

# Run all security checks
checkFileVault
checkGatekeeper
checkFirewall
checkSIP
checkAutoLogin
checkRemoteLogin
checkSecureBoot
checkScreenLock

# Print summary
printSummary

# Exit with appropriate code
if [[ ${failedChecks} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
