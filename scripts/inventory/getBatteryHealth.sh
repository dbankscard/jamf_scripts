#!/bin/bash
#
#purpose: Output battery cycle count, condition, max capacity percentage
#date: January 2026
#

# Constants
SCRIPT_NAME="getBatteryHealth"
IOREG="/usr/sbin/ioreg"
SYSTEM_PROFILER="/usr/sbin/system_profiler"

# Function to check if device has a battery
hasBattery() {
    local batteryInfo
    batteryInfo=$("$IOREG" -r -c AppleSmartBattery 2>/dev/null)

    if [[ -z "$batteryInfo" ]]; then
        return 1
    fi
    return 0
}

# Function to get battery information
getBatteryInfo() {
    local cycleCount
    local maxCapacity
    local designCapacity
    local currentCapacity
    local batteryCondition
    local isCharging
    local fullyCharged
    local externalConnected
    local healthPercent

    # Get battery data from ioreg
    local batteryData
    batteryData=$("$IOREG" -r -c AppleSmartBattery 2>/dev/null)

    cycleCount=$(echo "$batteryData" | awk -F' = ' '/"CycleCount"/ {print $2}')
    maxCapacity=$(echo "$batteryData" | awk -F' = ' '/"AppleRawMaxCapacity"|"MaxCapacity"/ {print $2}' | head -1)
    designCapacity=$(echo "$batteryData" | awk -F' = ' '/"DesignCapacity"/ {print $2}')
    currentCapacity=$(echo "$batteryData" | awk -F' = ' '/"AppleRawCurrentCapacity"|"CurrentCapacity"/ {print $2}' | head -1)
    isCharging=$(echo "$batteryData" | awk -F' = ' '/"IsCharging"/ {print $2}')
    fullyCharged=$(echo "$batteryData" | awk -F' = ' '/"FullyCharged"/ {print $2}')
    externalConnected=$(echo "$batteryData" | awk -F' = ' '/"ExternalConnected"/ {print $2}')

    # Calculate health percentage
    if [[ -n "$maxCapacity" && -n "$designCapacity" && "$designCapacity" -gt 0 ]]; then
        healthPercent=$((maxCapacity * 100 / designCapacity))
    else
        healthPercent="Unknown"
    fi

    # Get battery condition from system_profiler
    batteryCondition=$("$SYSTEM_PROFILER" SPPowerDataType 2>/dev/null | awk -F': ' '/Condition/ {print $2}')

    # Determine charging status
    local chargingStatus
    if [[ "$isCharging" == "Yes" ]]; then
        chargingStatus="Charging"
    elif [[ "$fullyCharged" == "Yes" ]]; then
        chargingStatus="Fully Charged"
    elif [[ "$externalConnected" == "Yes" ]]; then
        chargingStatus="Connected (Not Charging)"
    else
        chargingStatus="On Battery"
    fi

    echo "Cycle Count: ${cycleCount:-Unknown}"
    echo "Battery Condition: ${batteryCondition:-Unknown}"
    echo "Health Percentage: ${healthPercent}%"
    echo "Design Capacity: ${designCapacity:-Unknown} mAh"
    echo "Max Capacity: ${maxCapacity:-Unknown} mAh"
    echo "Current Capacity: ${currentCapacity:-Unknown} mAh"
    echo "Charging Status: ${chargingStatus}"
}

# Function to get power adapter info
getPowerAdapterInfo() {
    local adapterInfo
    adapterInfo=$("$SYSTEM_PROFILER" SPPowerDataType 2>/dev/null)

    local adapterConnected
    local adapterWattage

    adapterConnected=$(echo "$adapterInfo" | awk -F': ' '/Connected/ {print $2}' | head -1)
    adapterWattage=$(echo "$adapterInfo" | awk -F': ' '/Wattage/ {print $2}')

    echo "AC Power Connected: ${adapterConnected:-Unknown}"
    if [[ -n "$adapterWattage" ]]; then
        echo "Adapter Wattage: ${adapterWattage}"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Battery Health Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    if ! hasBattery; then
        echo "This device does not have a battery (Desktop Mac)"
        echo "======================================"
        exit 0
    fi

    echo "--- Battery Information ---"
    getBatteryInfo
    echo ""
    echo "--- Power Adapter ---"
    getPowerAdapterInfo
    echo ""
    echo "======================================"
}

# Run main function
main

exit 0
