#!/bin/bash
#
#purpose: Output serial number and warranty lookup URL (can't query Apple directly)
#date: January 2026
#

# Constants
SCRIPT_NAME="getHardwareWarranty"
SYSTEM_PROFILER="/usr/sbin/system_profiler"
APPLE_COVERAGE_URL="https://checkcoverage.apple.com"

# Function to get serial number
getSerialNumber() {
    local serialNumber

    # Try system_profiler first
    serialNumber=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/ {print $2}')

    # Fallback to ioreg if system_profiler fails
    if [[ -z "$serialNumber" ]]; then
        serialNumber=$(ioreg -l 2>/dev/null | awk -F'"' '/IOPlatformSerialNumber/ {print $4}')
    fi

    echo "${serialNumber:-Unknown}"
}

# Function to get hardware model
getHardwareModel() {
    local modelName
    local modelIdentifier

    modelName=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/ {print $2}')
    modelIdentifier=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Identifier/ {print $2}')

    echo "Model Name: ${modelName:-Unknown}"
    echo "Model Identifier: ${modelIdentifier:-Unknown}"
}

# Function to get hardware UUID
getHardwareUUID() {
    local hardwareUUID

    hardwareUUID=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null | awk -F': ' '/Hardware UUID/ {print $2}')

    echo "${hardwareUUID:-Unknown}"
}

# Function to get provisioning UDID
getProvisioningUDID() {
    local udid

    udid=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null | awk -F': ' '/Provisioning UDID/ {print $2}')

    echo "${udid:-Not Available}"
}

# Function to estimate Mac age based on serial number
estimateMacAge() {
    local serial="$1"

    if [[ -z "$serial" || "$serial" == "Unknown" ]]; then
        echo "Unable to estimate age"
        return 1
    fi

    # Serial number format changed over time
    local serialLength=${#serial}

    if [[ "$serialLength" -eq 12 ]]; then
        # New format (2010+): Character 4 is the year, Character 5 is the week
        local yearCode="${serial:3:1}"
        local weekCode="${serial:4:1}"

        # Year codes (C=2010, D=2011, F=2012, G=2013, H=2014, J=2015, K=2016, L=2017, M=2018, N=2019, P=2020, Q=2021, R=2022, T=2023, V=2024, W=2025)
        local year=""
        case "$yearCode" in
            C) year="2010" ;;
            D) year="2011" ;;
            F) year="2012" ;;
            G) year="2013" ;;
            H) year="2014" ;;
            J) year="2015" ;;
            K) year="2016" ;;
            L) year="2017" ;;
            M) year="2018" ;;
            N) year="2019" ;;
            P) year="2020" ;;
            Q) year="2021" ;;
            R) year="2022" ;;
            T) year="2023" ;;
            V) year="2024" ;;
            W) year="2025" ;;
            *) year="Unknown" ;;
        esac

        # Week codes (1-9 for weeks 1-9, C-Y for weeks 10-35, etc.)
        local week=""
        case "$weekCode" in
            [1-9]) week="$weekCode" ;;
            C) week="10" ;;
            D) week="11" ;;
            F) week="12" ;;
            G) week="13" ;;
            H) week="14" ;;
            J) week="15" ;;
            K) week="16" ;;
            L) week="17" ;;
            M) week="18" ;;
            N) week="19" ;;
            P) week="20" ;;
            Q) week="21" ;;
            R) week="22" ;;
            T) week="23" ;;
            V) week="24" ;;
            W) week="25" ;;
            X) week="26" ;;
            Y) week="27" ;;
            *) week="Unknown" ;;
        esac

        if [[ "$year" != "Unknown" && "$week" != "Unknown" ]]; then
            echo "Estimated Manufacture Date: ${year}, Week ${week}"

            # Calculate approximate age
            local currentYear
            currentYear=$(date +%Y)
            local ageYears=$((currentYear - year))
            echo "Approximate Age: ${ageYears} years"
        else
            echo "Unable to determine manufacture date from serial"
        fi
    elif [[ "$serialLength" -eq 10 ]]; then
        # Randomized serial format (2021+ for some models)
        echo "Randomized Serial Number Format"
        echo "Manufacture date cannot be determined from serial"
    else
        echo "Unrecognized serial number format"
    fi
}

# Function to get purchase information if available
getPurchaseInfo() {
    # Check for Apple registration information
    local registrationPlist="/Library/Preferences/com.apple.RemoteDesktop.plist"

    # Note: Purchase date is typically not stored locally
    # This would need to be queried from MDM or company records

    echo "Note: Purchase date and warranty information must be looked up"
    echo "using Apple's coverage check website or your organization's"
    echo "asset management system."
}

# Function to generate warranty lookup URLs
generateWarrantyURLs() {
    local serialNumber="$1"

    if [[ -z "$serialNumber" || "$serialNumber" == "Unknown" ]]; then
        echo "Serial number not available - cannot generate lookup URLs"
        return 1
    fi

    echo "Apple Coverage Check:"
    echo "  $APPLE_COVERAGE_URL"
    echo ""
    echo "Direct Link (enter serial manually):"
    echo "  ${APPLE_COVERAGE_URL}/checkcoverage"
    echo ""
    echo "Apple Support:"
    echo "  https://support.apple.com/en-us"
    echo ""
    echo "Alternative Lookup Services:"
    echo "  https://everymac.com/ultimate-mac-lookup/"
}

# Function to check for AppleCare evidence
checkAppleCareEvidence() {
    # Check for AppleCare-related profiles
    local acProfiles
    acProfiles=$(profiles list 2>/dev/null | grep -i "applecare")

    if [[ -n "$acProfiles" ]]; then
        echo "AppleCare Profile Detected: Yes"
    else
        echo "AppleCare Profile Detected: No"
    fi

    # Note: Actual AppleCare status must be checked with Apple
    echo ""
    echo "Note: AppleCare status must be verified through Apple's"
    echo "official coverage check tool."
}

# Function to get chip/processor info for warranty context
getChipInfo() {
    local chipInfo

    chipInfo=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null | awk -F': ' '/Chip|Processor Name/ {print $2}' | head -1)

    if [[ "$chipInfo" == *"Apple"* ]]; then
        echo "Processor: $chipInfo (Apple Silicon)"
    else
        echo "Processor: ${chipInfo:-Unknown} (Intel)"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Hardware Warranty Information Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    local serialNumber
    serialNumber=$(getSerialNumber)

    echo "--- Hardware Identification ---"
    getHardwareModel
    getChipInfo
    echo "Serial Number: $serialNumber"
    echo "Hardware UUID: $(getHardwareUUID)"
    echo "Provisioning UDID: $(getProvisioningUDID)"
    echo ""

    echo "--- Manufacture Date Estimate ---"
    estimateMacAge "$serialNumber"
    echo ""

    echo "--- AppleCare Status ---"
    checkAppleCareEvidence
    echo ""

    echo "--- Warranty Lookup URLs ---"
    generateWarrantyURLs "$serialNumber"
    echo ""

    echo "--- Important Notes ---"
    getPurchaseInfo
    echo ""

    echo "======================================"
    echo ""
    echo "To check warranty status:"
    echo "1. Visit: $APPLE_COVERAGE_URL"
    echo "2. Enter Serial Number: $serialNumber"
    echo "3. Complete verification to view coverage details"
    echo "======================================"
}

# Run main function
main

exit 0
