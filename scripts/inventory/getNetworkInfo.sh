#!/bin/bash
#
#purpose: Output network config: IP, MAC, DNS servers, gateway, WiFi SSID
#date: January 2026
#

# Constants
SCRIPT_NAME="getNetworkInfo"
NETWORKSETUP="/usr/sbin/networksetup"
IPCONFIG="/usr/sbin/ipconfig"

# Function to get primary network interface
getPrimaryInterface() {
    local primaryInterface
    primaryInterface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    echo "${primaryInterface:-Unknown}"
}

# Function to get IP address for an interface
getIPAddress() {
    local interface="$1"
    local ipAddress
    ipAddress=$("$IPCONFIG" getifaddr "$interface" 2>/dev/null)
    echo "${ipAddress:-Not Connected}"
}

# Function to get MAC address for an interface
getMACAddress() {
    local interface="$1"
    local macAddress
    macAddress=$(ifconfig "$interface" 2>/dev/null | awk '/ether/ {print $2}')
    echo "${macAddress:-Unknown}"
}

# Function to get subnet mask
getSubnetMask() {
    local interface="$1"
    local subnetMask
    subnetMask=$(ifconfig "$interface" 2>/dev/null | awk '/netmask/ {print $4}')

    # Convert hex to decimal if needed
    if [[ "$subnetMask" =~ ^0x ]]; then
        local hex="${subnetMask#0x}"
        local o1=$((16#${hex:0:2}))
        local o2=$((16#${hex:2:2}))
        local o3=$((16#${hex:4:2}))
        local o4=$((16#${hex:6:2}))
        subnetMask="${o1}.${o2}.${o3}.${o4}"
    fi

    echo "${subnetMask:-Unknown}"
}

# Function to get default gateway
getDefaultGateway() {
    local gateway
    gateway=$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')
    echo "${gateway:-Unknown}"
}

# Function to get DNS servers
getDNSServers() {
    local dnsServers
    dnsServers=$(scutil --dns 2>/dev/null | awk '/nameserver\[/ {print $3}' | sort -u | tr '\n' ', ' | sed 's/,$//')
    echo "${dnsServers:-Unknown}"
}

# Function to get WiFi information
getWiFiInfo() {
    local wifiInterface
    wifiInterface=$("$NETWORKSETUP" -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort/{getline; print $2}')

    if [[ -z "$wifiInterface" ]]; then
        echo "WiFi Interface: Not Found"
        return 1
    fi

    echo "WiFi Interface: $wifiInterface"

    # Check if WiFi is enabled
    local wifiPower
    wifiPower=$("$NETWORKSETUP" -getairportpower "$wifiInterface" 2>/dev/null | awk '{print $NF}')
    echo "WiFi Power: ${wifiPower:-Unknown}"

    if [[ "$wifiPower" == "On" ]]; then
        # Get current network using airport command
        local airportPath="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"

        if [[ -x "$airportPath" ]]; then
            local ssid
            local bssid
            local channel
            local rssi
            local securityType

            ssid=$("$airportPath" -I 2>/dev/null | awk -F': ' '/ SSID:/ {print $2}')
            bssid=$("$airportPath" -I 2>/dev/null | awk -F': ' '/BSSID:/ {print $2}')
            channel=$("$airportPath" -I 2>/dev/null | awk -F': ' '/channel:/ {print $2}')
            rssi=$("$airportPath" -I 2>/dev/null | awk -F': ' '/agrCtlRSSI:/ {print $2}')
            securityType=$("$airportPath" -I 2>/dev/null | awk -F': ' '/link auth:/ {print $2}')

            echo "Connected SSID: ${ssid:-Not Connected}"
            echo "BSSID: ${bssid:-Unknown}"
            echo "Channel: ${channel:-Unknown}"
            echo "Signal Strength (RSSI): ${rssi:-Unknown} dBm"
            echo "Security Type: ${securityType:-Unknown}"
        else
            # Fallback method using networksetup
            local currentNetwork
            currentNetwork=$("$NETWORKSETUP" -getairportnetwork "$wifiInterface" 2>/dev/null | awk -F': ' '{print $2}')
            echo "Connected SSID: ${currentNetwork:-Not Connected}"
        fi
    fi
}

# Function to get Ethernet information
getEthernetInfo() {
    local ethernetInterface
    ethernetInterface=$("$NETWORKSETUP" -listallhardwareports 2>/dev/null | awk '/Ethernet/{getline; print $2}' | head -1)

    if [[ -z "$ethernetInterface" ]]; then
        echo "Ethernet Interface: Not Found"
        return 1
    fi

    echo "Ethernet Interface: $ethernetInterface"

    local ipAddress
    local macAddress

    ipAddress=$(getIPAddress "$ethernetInterface")
    macAddress=$(getMACAddress "$ethernetInterface")

    echo "IP Address: $ipAddress"
    echo "MAC Address: $macAddress"
}

# Function to get public IP address
getPublicIP() {
    local publicIP
    publicIP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null)
    echo "${publicIP:-Unable to determine}"
}

# Main execution
main() {
    echo "======================================"
    echo "Network Information Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    local primaryInterface
    primaryInterface=$(getPrimaryInterface)

    echo "--- Primary Network Interface ---"
    echo "Interface: $primaryInterface"

    if [[ "$primaryInterface" != "Unknown" ]]; then
        echo "IP Address: $(getIPAddress "$primaryInterface")"
        echo "MAC Address: $(getMACAddress "$primaryInterface")"
        echo "Subnet Mask: $(getSubnetMask "$primaryInterface")"
    fi

    echo "Default Gateway: $(getDefaultGateway)"
    echo "DNS Servers: $(getDNSServers)"
    echo ""

    echo "--- WiFi Information ---"
    getWiFiInfo
    echo ""

    echo "--- Ethernet Information ---"
    getEthernetInfo
    echo ""

    echo "--- External IP ---"
    echo "Public IP: $(getPublicIP)"
    echo ""

    echo "======================================"
}

# Run main function
main

exit 0
