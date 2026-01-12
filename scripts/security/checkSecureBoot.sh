#!/bin/bash

#purpose: Check Secure Boot status on Apple Silicon Macs
#date: January 2026

# Constants
SCRIPT_NAME="checkSecureBoot"
LOG_TAG="[${SCRIPT_NAME}]"

# Functions
logMessage() {
    local message="$1"
    echo "${LOG_TAG} ${message}"
    /usr/bin/logger -t "${SCRIPT_NAME}" "${message}"
}

getArchitecture() {
    local arch
    arch=$(/usr/bin/uname -m)
    echo "${arch}"
}

getCPUBrand() {
    local cpuBrand
    cpuBrand=$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    echo "${cpuBrand}"
}

checkT2Chip() {
    local t2Count
    t2Count=$(/usr/sbin/ioreg -l 2>/dev/null | grep -c "AppleT2Controller" || echo "0")
    echo "${t2Count}"
}

# Main script
logMessage "Starting Secure Boot status check..."

# Get system information
architecture=$(getArchitecture)
cpuBrand=$(getCPUBrand)

logMessage "Architecture: ${architecture}"
logMessage "CPU: ${cpuBrand}"

# Determine if this is Apple Silicon or Intel
if [[ "${architecture}" == "arm64" ]] || echo "${cpuBrand}" | grep -qi "Apple"; then
    # Apple Silicon Mac
    logMessage "Detected: Apple Silicon Mac"

    # Check boot policy using bputil
    if [[ -x /usr/sbin/bputil ]]; then
        logMessage "Checking boot policy with bputil..."

        # Get boot policy display
        bootPolicyOutput=$(/usr/sbin/bputil -d 2>&1)
        bputilExitCode=$?

        if [[ ${bputilExitCode} -eq 0 ]]; then
            logMessage "Boot Policy Output:"
            echo "${bootPolicyOutput}" | while read -r line; do
                logMessage "  ${line}"
            done

            # Parse security mode
            if echo "${bootPolicyOutput}" | grep -qi "Full Security"; then
                logMessage "Secure Boot Status: FULL SECURITY"
                logMessage "STATUS: COMPLIANT - Maximum security boot mode is enabled"
                securityLevel="Full"
            elif echo "${bootPolicyOutput}" | grep -qi "Reduced Security"; then
                logMessage "Secure Boot Status: REDUCED SECURITY"
                logMessage "WARNING: Reduced security mode allows some unsigned kernel extensions"
                logMessage "STATUS: PARTIALLY COMPLIANT - Consider enabling Full Security"
                securityLevel="Reduced"
            elif echo "${bootPolicyOutput}" | grep -qi "Permissive Security"; then
                logMessage "Secure Boot Status: PERMISSIVE SECURITY"
                logMessage "WARNING: Permissive security mode - lowest security setting"
                logMessage "STATUS: NON-COMPLIANT - Strongly recommend enabling Full Security"
                securityLevel="Permissive"
            else
                logMessage "Secure Boot Status: UNKNOWN"
                logMessage "Unable to determine security level from bputil output"
                securityLevel="Unknown"
            fi
        else
            logMessage "WARNING: bputil returned an error"
            logMessage "Error output: ${bootPolicyOutput}"

            # Alternative: try to get info from system_profiler
            logMessage "Attempting alternative check via system_profiler..."
            hardwareInfo=$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null)
            logMessage "System is Apple Silicon - Secure Boot is supported"
            securityLevel="Unknown"
        fi
    else
        logMessage "WARNING: bputil not found"
        logMessage "System appears to be Apple Silicon - Secure Boot should be available"
        securityLevel="Unknown"
    fi

    # Additional Apple Silicon security checks
    logMessage "Additional Security Checks:"

    # Check for Startup Security Utility settings
    if [[ -x /usr/bin/csrutil ]]; then
        sipStatus=$(/usr/bin/csrutil status 2>&1)
        logMessage "SIP Status: ${sipStatus}"
    fi

else
    # Intel Mac
    logMessage "Detected: Intel Mac"

    # Check for T2 chip
    t2Present=$(checkT2Chip)

    if [[ "${t2Present}" -gt 0 ]]; then
        logMessage "T2 Security Chip: PRESENT"

        # T2 chip provides Secure Boot on Intel Macs
        logMessage "Secure Boot capability: AVAILABLE (via T2 chip)"

        # Check secure boot policy if possible
        # Note: On Intel Macs with T2, secure boot settings are in Startup Security Utility
        logMessage "NOTE: Secure Boot settings can be configured in Startup Security Utility"
        logMessage "      (Available in Recovery Mode)"

        # Check for Full Security indicators
        logMessage "Checking T2 security indicators..."

        # Get hardware info
        hardwareOverview=$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null)
        if echo "${hardwareOverview}" | grep -qi "T2"; then
            logMessage "T2 chip confirmed in hardware profile"
        fi

        logMessage "STATUS: T2 SECURE BOOT AVAILABLE"
        logMessage "NOTE: Boot security level must be verified in Recovery Mode"
        securityLevel="T2-Available"

    else
        logMessage "T2 Security Chip: NOT PRESENT"
        logMessage "Secure Boot: NOT AVAILABLE"
        logMessage "NOTE: This Intel Mac does not have a T2 chip"
        logMessage "      Secure Boot is only available on Intel Macs with T2 chip"
        logMessage "      or Apple Silicon Macs"
        logMessage "STATUS: NOT APPLICABLE - No hardware Secure Boot support"
        securityLevel="NotApplicable"
    fi
fi

# Summary
logMessage "============================================"
logMessage "Secure Boot Check Summary"
logMessage "============================================"
logMessage "Architecture: ${architecture}"
logMessage "CPU: ${cpuBrand}"
logMessage "Security Level: ${securityLevel}"
logMessage "============================================"

# Exit based on security level
case "${securityLevel}" in
    "Full"|"T2-Available")
        exit 0
        ;;
    "Reduced"|"Unknown")
        exit 0
        ;;
    "Permissive")
        exit 1
        ;;
    "NotApplicable")
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
