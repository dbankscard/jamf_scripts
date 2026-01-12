#!/bin/bash
#
#purpose: Summary of security settings: FileVault, Gatekeeper, SIP, Firewall status
#date: January 2026
#

# Constants
SCRIPT_NAME="getSecurityInfo"

# Function to get FileVault status
getFileVaultStatus() {
    local fdeStatus
    fdeStatus=$(fdesetup status 2>/dev/null)

    if [[ "$fdeStatus" == *"FileVault is On"* ]]; then
        echo "Status: Enabled"

        # Check encryption progress
        if [[ "$fdeStatus" == *"Encryption in progress"* ]]; then
            local progress
            progress=$(echo "$fdeStatus" | grep -o "Percent.*")
            echo "Progress: $progress"
        elif [[ "$fdeStatus" == *"Decryption in progress"* ]]; then
            local progress
            progress=$(echo "$fdeStatus" | grep -o "Percent.*")
            echo "Progress: Decryption - $progress"
        else
            echo "Encryption: Complete"
        fi

        # List FileVault users
        local fvUsers
        fvUsers=$(fdesetup list 2>/dev/null | awk -F',' '{print $1}' | tr '\n' ', ' | sed 's/,$//')
        if [[ -n "$fvUsers" ]]; then
            echo "Enabled Users: $fvUsers"
        fi
    elif [[ "$fdeStatus" == *"FileVault is Off"* ]]; then
        echo "Status: Disabled"
    else
        echo "Status: Unknown"
    fi
}

# Function to get Gatekeeper status
getGatekeeperStatus() {
    local gkStatus
    gkStatus=$(spctl --status 2>/dev/null)

    if [[ "$gkStatus" == *"assessments enabled"* ]]; then
        echo "Status: Enabled"
    elif [[ "$gkStatus" == *"assessments disabled"* ]]; then
        echo "Status: Disabled"
    else
        echo "Status: Unknown"
    fi

    # Get the configured level (if available)
    local gkMaster
    gkMaster=$(spctl --status 2>&1)

    # Check for developer ID settings
    local developerID
    developerID=$(spctl --status --verbose 2>/dev/null | grep -i "developer")
    if [[ -n "$developerID" ]]; then
        echo "Developer ID: Allowed"
    fi
}

# Function to get System Integrity Protection status
getSIPStatus() {
    local sipStatus
    sipStatus=$(csrutil status 2>/dev/null)

    if [[ "$sipStatus" == *"enabled"* ]]; then
        echo "Status: Enabled"
    elif [[ "$sipStatus" == *"disabled"* ]]; then
        echo "Status: Disabled"
    elif [[ "$sipStatus" == *"unknown"* ]]; then
        echo "Status: Unknown (custom configuration)"
    else
        echo "Status: Unknown"
    fi

    # Check for custom configuration
    if [[ "$sipStatus" == *"Custom Configuration"* ]]; then
        echo "Configuration: Custom"
    fi
}

# Function to get Firewall status
getFirewallStatus() {
    local fwStatus

    # Try socketfilterfw first (modern method)
    fwStatus=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)

    if [[ "$fwStatus" == *"enabled"* ]]; then
        echo "Status: Enabled"

        # Get additional firewall settings
        local blockAll
        blockAll=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null)
        if [[ "$blockAll" == *"ENABLED"* ]]; then
            echo "Block All Incoming: Enabled"
        else
            echo "Block All Incoming: Disabled"
        fi

        local stealthMode
        stealthMode=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null)
        if [[ "$stealthMode" == *"enabled"* ]]; then
            echo "Stealth Mode: Enabled"
        else
            echo "Stealth Mode: Disabled"
        fi

        local signedApps
        signedApps=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null)
        if [[ "$signedApps" == *"ENABLED"* ]]; then
            echo "Allow Signed Apps: Enabled"
        else
            echo "Allow Signed Apps: Disabled"
        fi
    elif [[ "$fwStatus" == *"disabled"* ]]; then
        echo "Status: Disabled"
    else
        echo "Status: Unknown"
    fi
}

# Function to get Secure Boot status (Apple Silicon/T2)
getSecureBootStatus() {
    local sbStatus

    # Check for Apple Silicon or T2
    local hasSecureBoot=false

    # Check for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        hasSecureBoot=true
    fi

    # Check for T2 chip
    local t2Check
    t2Check=$(system_profiler SPiBridgeDataType 2>/dev/null | grep -i "T2")
    if [[ -n "$t2Check" ]]; then
        hasSecureBoot=true
    fi

    if [[ "$hasSecureBoot" == true ]]; then
        # Try to get boot policy
        sbStatus=$(bputil -d 2>/dev/null | grep -i "security" | head -1)

        if [[ -n "$sbStatus" ]]; then
            echo "Secure Boot: $sbStatus"
        else
            echo "Secure Boot: Supported (details require authentication)"
        fi
    else
        echo "Secure Boot: Not Available (Intel Mac without T2)"
    fi
}

# Function to check XProtect status
getXProtectStatus() {
    local xprotectVersion
    local xprotectPath="/Library/Apple/System/Library/CoreServices/XProtect.bundle"
    local xprotectPlistPath="$xprotectPath/Contents/Resources/XProtect.meta.plist"

    if [[ -d "$xprotectPath" ]]; then
        echo "XProtect: Installed"

        # Get version
        if [[ -f "$xprotectPath/Contents/Info.plist" ]]; then
            xprotectVersion=$(/usr/bin/defaults read "$xprotectPath/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
            echo "Version: ${xprotectVersion:-Unknown}"
        fi

        # Get definition version
        if [[ -f "$xprotectPlistPath" ]]; then
            local defVersion
            defVersion=$(/usr/bin/defaults read "$xprotectPlistPath" Version 2>/dev/null)
            echo "Definitions Version: ${defVersion:-Unknown}"
        fi
    else
        # Check legacy location
        local legacyPath="/System/Library/CoreServices/XProtect.bundle"
        if [[ -d "$legacyPath" ]]; then
            echo "XProtect: Installed (Legacy Location)"
        else
            echo "XProtect: Not Found"
        fi
    fi
}

# Function to check MRT (Malware Removal Tool) status
getMRTStatus() {
    local mrtPath="/Library/Apple/System/Library/CoreServices/MRT.app"
    local legacyMrtPath="/System/Library/CoreServices/MRT.app"

    if [[ -d "$mrtPath" ]]; then
        local mrtVersion
        mrtVersion=$(/usr/bin/defaults read "$mrtPath/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)
        echo "MRT: Installed"
        echo "Version: ${mrtVersion:-Unknown}"
    elif [[ -d "$legacyMrtPath" ]]; then
        echo "MRT: Installed (Legacy Location)"
    else
        echo "MRT: Not Found"
    fi
}

# Function to check password policy
getPasswordPolicyStatus() {
    local pwPolicy
    pwPolicy=$(pwpolicy -getaccountpolicies 2>/dev/null)

    if [[ -n "$pwPolicy" && "$pwPolicy" != *"Error"* ]]; then
        echo "Password Policy: Configured"
    else
        echo "Password Policy: Default/Not Configured"
    fi
}

# Function to check remote access services
getRemoteAccessStatus() {
    # Check SSH
    local sshStatus
    sshStatus=$(systemsetup -getremotelogin 2>/dev/null | awk '{print $NF}')
    echo "Remote Login (SSH): ${sshStatus:-Unknown}"

    # Check Screen Sharing
    local screenSharing
    screenSharing=$(launchctl list 2>/dev/null | grep -c "screensharing")
    if [[ "$screenSharing" -gt 0 ]]; then
        echo "Screen Sharing: Enabled"
    else
        echo "Screen Sharing: Disabled"
    fi

    # Check Remote Management (ARD)
    local ardStatus
    ardStatus=$(launchctl list 2>/dev/null | grep -c "com.apple.RemoteDesktop")
    if [[ "$ardStatus" -gt 0 ]]; then
        echo "Remote Management (ARD): Running"
    else
        echo "Remote Management (ARD): Not Running"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Security Information Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    echo "--- FileVault (Full Disk Encryption) ---"
    getFileVaultStatus
    echo ""

    echo "--- Gatekeeper ---"
    getGatekeeperStatus
    echo ""

    echo "--- System Integrity Protection (SIP) ---"
    getSIPStatus
    echo ""

    echo "--- Application Firewall ---"
    getFirewallStatus
    echo ""

    echo "--- Secure Boot ---"
    getSecureBootStatus
    echo ""

    echo "--- XProtect (Malware Detection) ---"
    getXProtectStatus
    echo ""

    echo "--- Malware Removal Tool (MRT) ---"
    getMRTStatus
    echo ""

    echo "--- Password Policy ---"
    getPasswordPolicyStatus
    echo ""

    echo "--- Remote Access Services ---"
    getRemoteAccessStatus
    echo ""

    echo "======================================"
}

# Run main function
main

exit 0
