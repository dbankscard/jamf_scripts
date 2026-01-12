#!/bin/bash
#
#purpose: Output comprehensive system info: Model, macOS version, serial, processor, RAM, uptime
#date: January 2026
#

# Constants
SCRIPT_NAME="getSystemInfo"
SYSTEM_PROFILER="/usr/sbin/system_profiler"

# Function to get hardware info
getHardwareInfo() {
    local hardwareInfo
    hardwareInfo=$("$SYSTEM_PROFILER" SPHardwareDataType 2>/dev/null)

    if [[ -z "$hardwareInfo" ]]; then
        echo "<result>Error: Unable to retrieve hardware information</result>"
        exit 1
    fi

    # Extract values
    local modelName
    local modelIdentifier
    local serialNumber
    local processorName
    local processorCores
    local memorySize

    modelName=$(echo "$hardwareInfo" | awk -F': ' '/Model Name/ {print $2}')
    modelIdentifier=$(echo "$hardwareInfo" | awk -F': ' '/Model Identifier/ {print $2}')
    serialNumber=$(echo "$hardwareInfo" | awk -F': ' '/Serial Number/ {print $2}')
    processorName=$(echo "$hardwareInfo" | awk -F': ' '/Chip|Processor Name/ {print $2}' | head -1)
    processorCores=$(echo "$hardwareInfo" | awk -F': ' '/Total Number of Cores/ {print $2}')
    memorySize=$(echo "$hardwareInfo" | awk -F': ' '/Memory/ {print $2}')

    echo "Model Name: ${modelName:-Unknown}"
    echo "Model Identifier: ${modelIdentifier:-Unknown}"
    echo "Serial Number: ${serialNumber:-Unknown}"
    echo "Processor: ${processorName:-Unknown}"
    echo "Processor Cores: ${processorCores:-Unknown}"
    echo "Memory: ${memorySize:-Unknown}"
}

# Function to get macOS version info
getOSInfo() {
    local osVersion
    local osBuild
    local osName

    osVersion=$(sw_vers -productVersion 2>/dev/null)
    osBuild=$(sw_vers -buildVersion 2>/dev/null)
    osName=$(sw_vers -productName 2>/dev/null)

    echo "OS Name: ${osName:-Unknown}"
    echo "OS Version: ${osVersion:-Unknown}"
    echo "OS Build: ${osBuild:-Unknown}"
}

# Function to get uptime
getUptimeInfo() {
    local bootTime
    local uptimeSeconds
    local uptimeDays
    local uptimeHours
    local uptimeMinutes

    bootTime=$(sysctl -n kern.boottime 2>/dev/null | awk -F'[= ,]' '{print $6}')

    if [[ -n "$bootTime" ]]; then
        local currentTime
        currentTime=$(date +%s)
        uptimeSeconds=$((currentTime - bootTime))
        uptimeDays=$((uptimeSeconds / 86400))
        uptimeHours=$(((uptimeSeconds % 86400) / 3600))
        uptimeMinutes=$(((uptimeSeconds % 3600) / 60))
        echo "Uptime: ${uptimeDays} days, ${uptimeHours} hours, ${uptimeMinutes} minutes"
    else
        echo "Uptime: Unknown"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "System Information Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""
    echo "--- Hardware Information ---"
    getHardwareInfo
    echo ""
    echo "--- Operating System ---"
    getOSInfo
    echo ""
    echo "--- System Uptime ---"
    getUptimeInfo
    echo ""
    echo "======================================"
}

# Run main function
main

exit 0
