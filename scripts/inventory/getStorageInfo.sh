#!/bin/bash
#
#purpose: Output storage details: disk size, free space, APFS volumes, encryption status
#date: January 2026
#

# Constants
SCRIPT_NAME="getStorageInfo"
DISKUTIL="/usr/sbin/diskutil"

# Function to get boot volume info
getBootVolumeInfo() {
    local bootVolume
    bootVolume=$(df / 2>/dev/null | tail -1 | awk '{print $1}')

    echo "Boot Volume: ${bootVolume:-Unknown}"
}

# Function to convert bytes to human readable
bytesToHuman() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    local result=$bytes

    while [[ $(echo "$result >= 1024" | bc -l 2>/dev/null) -eq 1 && $unit -lt 4 ]]; do
        result=$(echo "scale=2; $result / 1024" | bc -l 2>/dev/null)
        ((unit++))
    done

    printf "%.2f %s" "$result" "${units[$unit]}"
}

# Function to get disk space using df
getDiskSpaceInfo() {
    local totalBlocks
    local usedBlocks
    local availBlocks
    local capacity

    # Get info for root filesystem
    local dfOutput
    dfOutput=$(df -k / 2>/dev/null | tail -1)

    totalBlocks=$(echo "$dfOutput" | awk '{print $2}')
    usedBlocks=$(echo "$dfOutput" | awk '{print $3}')
    availBlocks=$(echo "$dfOutput" | awk '{print $4}')
    capacity=$(echo "$dfOutput" | awk '{print $5}')

    # Convert KB to bytes then to human readable
    if [[ -n "$totalBlocks" ]]; then
        local totalBytes=$((totalBlocks * 1024))
        local usedBytes=$((usedBlocks * 1024))
        local availBytes=$((availBlocks * 1024))

        echo "Total Disk Size: $(bytesToHuman $totalBytes)"
        echo "Used Space: $(bytesToHuman $usedBytes)"
        echo "Free Space: $(bytesToHuman $availBytes)"
        echo "Capacity Used: $capacity"
    fi
}

# Function to get APFS container info
getAPFSContainerInfo() {
    local apfsContainers
    apfsContainers=$("$DISKUTIL" apfs list 2>/dev/null)

    if [[ -z "$apfsContainers" ]]; then
        echo "No APFS containers found"
        return 1
    fi

    # Get container reference
    local containerRef
    containerRef=$(echo "$apfsContainers" | awk '/Container Reference:/ {print $3}' | head -1)

    if [[ -n "$containerRef" ]]; then
        echo "Container Reference: $containerRef"

        # Get container capacity
        local containerCapacity
        containerCapacity=$(echo "$apfsContainers" | awk '/Capacity Ceiling:/ {print $3, $4}' | head -1)
        echo "Container Capacity: ${containerCapacity:-Unknown}"

        # Get container free space
        local containerFree
        containerFree=$(echo "$apfsContainers" | awk '/Free Space:/ {print $3, $4}' | head -1)
        echo "Container Free Space: ${containerFree:-Unknown}"
    fi
}

# Function to list APFS volumes
listAPFSVolumes() {
    local volumeList
    volumeList=$("$DISKUTIL" apfs list 2>/dev/null | awk '/Volume [a-z0-9]+:/{flag=1} flag && /Name:/{print $2; flag=0}')

    if [[ -z "$volumeList" ]]; then
        echo "No APFS volumes found"
        return 1
    fi

    echo "APFS Volumes:"

    # Get all volume info from diskutil
    while IFS= read -r volumeName; do
        if [[ -n "$volumeName" ]]; then
            local volumeInfo
            volumeInfo=$("$DISKUTIL" info "$volumeName" 2>/dev/null)

            local mountPoint
            local volumeSize
            local volumeType

            mountPoint=$(echo "$volumeInfo" | awk -F': +' '/Mount Point:/ {print $2}')
            volumeSize=$(echo "$volumeInfo" | awk -F': +' '/Volume Total Space:|Disk Size:/ {print $2}' | head -1)
            volumeType=$(echo "$volumeInfo" | awk -F': +' '/Type \(Bundle\):/ {print $2}')

            if [[ -n "$mountPoint" || -n "$volumeSize" ]]; then
                printf "  - %s: Size: %s, Mount: %s\n" "$volumeName" "${volumeSize:-Unknown}" "${mountPoint:-Not Mounted}"
            fi
        fi
    done <<< "$volumeList"
}

# Function to get FileVault encryption status
getEncryptionStatus() {
    local fdeStatus
    fdeStatus=$(fdesetup status 2>/dev/null)

    if [[ "$fdeStatus" == *"FileVault is On"* ]]; then
        echo "FileVault Status: Enabled"

        # Check if encryption is in progress
        if [[ "$fdeStatus" == *"Encryption in progress"* ]]; then
            local progress
            progress=$(fdesetup status 2>/dev/null | awk '/Encryption in progress/ {print}')
            echo "Encryption Progress: $progress"
        fi
    elif [[ "$fdeStatus" == *"FileVault is Off"* ]]; then
        echo "FileVault Status: Disabled"
    else
        echo "FileVault Status: Unknown"
    fi

    # Get APFS encryption for boot volume
    local bootDisk
    bootDisk=$("$DISKUTIL" info / 2>/dev/null | awk -F': +' '/Device Identifier:/ {print $2}')

    if [[ -n "$bootDisk" ]]; then
        local apfsEncryption
        apfsEncryption=$("$DISKUTIL" apfs list 2>/dev/null | grep -A5 "$bootDisk" | awk '/FileVault:/ {print $2}')
        if [[ -n "$apfsEncryption" ]]; then
            echo "APFS Encryption: $apfsEncryption"
        fi
    fi
}

# Function to list all physical disks
listPhysicalDisks() {
    local diskList
    diskList=$("$DISKUTIL" list physical 2>/dev/null)

    if [[ -z "$diskList" ]]; then
        echo "Unable to retrieve physical disk information"
        return 1
    fi

    # Count physical disks
    local diskCount
    diskCount=$(echo "$diskList" | grep -c "^/dev/disk")

    echo "Physical Disks: $diskCount"
    echo ""

    # Get info for each physical disk
    for disk in $(echo "$diskList" | awk '/^\/dev\/disk/ {print $1}'); do
        local diskInfo
        diskInfo=$("$DISKUTIL" info "$disk" 2>/dev/null)

        local diskName
        local diskSize
        local diskType
        local mediaType

        diskName=$(echo "$diskInfo" | awk -F': +' '/Device \/ Media Name:/ {print $2}')
        diskSize=$(echo "$diskInfo" | awk -F': +' '/Disk Size:/ {print $2}')
        diskType=$(echo "$diskInfo" | awk -F': +' '/Content \(IOContent\):/ {print $2}')
        mediaType=$(echo "$diskInfo" | awk -F': +' '/Solid State:/ {if ($2 == "Yes") print "SSD"; else print "HDD"}')

        echo "  Disk: $disk"
        echo "    Name: ${diskName:-Unknown}"
        echo "    Size: ${diskSize:-Unknown}"
        echo "    Type: ${diskType:-Unknown}"
        echo "    Media: ${mediaType:-Unknown}"
        echo ""
    done
}

# Main execution
main() {
    echo "======================================"
    echo "Storage Information Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    echo "--- Boot Volume ---"
    getBootVolumeInfo
    echo ""

    echo "--- Disk Space ---"
    getDiskSpaceInfo
    echo ""

    echo "--- APFS Container ---"
    getAPFSContainerInfo
    echo ""

    echo "--- APFS Volumes ---"
    listAPFSVolumes
    echo ""

    echo "--- Encryption Status ---"
    getEncryptionStatus
    echo ""

    echo "--- Physical Disks ---"
    listPhysicalDisks

    echo "======================================"
}

# Run main function
main

exit 0
