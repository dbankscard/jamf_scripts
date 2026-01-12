#!/bin/bash
#
#purpose: List top 10 processes by CPU and memory usage
#date: January 2026
#

# Constants
SCRIPT_NAME="getRunningProcesses"
TOP_COUNT=10

# Function to get top processes by CPU
getTopCPUProcesses() {
    local topProcesses

    # Use ps to get processes sorted by CPU
    # %cpu - CPU percentage
    # %mem - Memory percentage
    # rss - Resident Set Size (actual memory)
    # pid - Process ID
    # user - User running the process
    # comm - Command name

    echo "Rank  PID      USER             %CPU   %MEM   COMMAND"
    echo "----  -------  ---------------  -----  -----  ---------------"

    ps aux 2>/dev/null | \
        awk 'NR>1 {print $2, $1, $3, $4, $11}' | \
        sort -k3 -rn | \
        head -n "$TOP_COUNT" | \
        awk '{printf "%-5d %-8s %-16s %5.1f  %5.1f  %s\n", NR, $1, $2, $3, $4, $5}'
}

# Function to get top processes by memory
getTopMemoryProcesses() {
    local topProcesses

    echo "Rank  PID      USER             %MEM   RSS(MB)  COMMAND"
    echo "----  -------  ---------------  -----  -------  ---------------"

    ps aux 2>/dev/null | \
        awk 'NR>1 {print $2, $1, $4, $6/1024, $11}' | \
        sort -k3 -rn | \
        head -n "$TOP_COUNT" | \
        awk '{printf "%-5d %-8s %-16s %5.1f  %7.1f  %s\n", NR, $1, $2, $3, $4, $5}'
}

# Function to get total process count
getProcessCount() {
    local processCount
    processCount=$(ps aux 2>/dev/null | wc -l | tr -d ' ')
    # Subtract 1 for header
    processCount=$((processCount - 1))
    echo "$processCount"
}

# Function to get system load averages
getLoadAverages() {
    local loadAvg
    loadAvg=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}')
    echo "${loadAvg:-Unknown}"
}

# Function to get CPU usage summary
getCPUUsage() {
    local cpuUsage

    # Use top in logging mode to get CPU stats
    cpuUsage=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage")

    if [[ -n "$cpuUsage" ]]; then
        local userCPU
        local sysCPU
        local idleCPU

        userCPU=$(echo "$cpuUsage" | awk -F'[:,]' '{print $2}' | tr -d ' ')
        sysCPU=$(echo "$cpuUsage" | awk -F'[:,]' '{print $3}' | tr -d ' ')
        idleCPU=$(echo "$cpuUsage" | awk -F'[:,]' '{print $4}' | tr -d ' ')

        echo "User: $userCPU"
        echo "System: $sysCPU"
        echo "Idle: $idleCPU"
    else
        echo "Unable to retrieve CPU usage"
    fi
}

# Function to get memory usage summary
getMemoryUsage() {
    local memInfo

    # Get physical memory size
    local physMem
    physMem=$(sysctl -n hw.memsize 2>/dev/null)
    local physMemGB=$((physMem / 1073741824))

    # Use vm_stat for memory statistics
    local vmStat
    vmStat=$(vm_stat 2>/dev/null)

    if [[ -n "$vmStat" ]]; then
        # Get page size (usually 4096 or 16384 on Apple Silicon)
        local pageSize
        pageSize=$(vm_stat 2>/dev/null | awk '/page size of/ {print $8}')

        # Get page counts
        local freePages
        local activePages
        local inactivePages
        local wiredPages
        local compressedPages

        freePages=$(echo "$vmStat" | awk '/Pages free:/ {print $3}' | tr -d '.')
        activePages=$(echo "$vmStat" | awk '/Pages active:/ {print $3}' | tr -d '.')
        inactivePages=$(echo "$vmStat" | awk '/Pages inactive:/ {print $3}' | tr -d '.')
        wiredPages=$(echo "$vmStat" | awk '/Pages wired down:/ {print $4}' | tr -d '.')
        compressedPages=$(echo "$vmStat" | awk '/Pages occupied by compressor:/ {print $5}' | tr -d '.')

        # Calculate memory in GB
        local freeMem=$((freePages * pageSize / 1073741824))
        local activeMem=$((activePages * pageSize / 1073741824))
        local inactiveMem=$((inactivePages * pageSize / 1073741824))
        local wiredMem=$((wiredPages * pageSize / 1073741824))
        local compressedMem=$((compressedPages * pageSize / 1073741824))
        local usedMem=$((activeMem + inactiveMem + wiredMem))

        echo "Physical Memory: ${physMemGB} GB"
        echo "Used: ~${usedMem} GB"
        echo "Active: ~${activeMem} GB"
        echo "Inactive: ~${inactiveMem} GB"
        echo "Wired: ~${wiredMem} GB"
        echo "Compressed: ~${compressedMem} GB"
        echo "Free: ~${freeMem} GB"
    else
        echo "Physical Memory: ${physMemGB} GB"
        echo "Details: Unable to retrieve"
    fi
}

# Function to list zombie processes
getZombieProcesses() {
    local zombieCount
    zombieCount=$(ps aux 2>/dev/null | awk '$8 ~ /Z/ {count++} END {print count+0}')

    echo "Zombie Processes: $zombieCount"

    if [[ "$zombieCount" -gt 0 ]]; then
        echo ""
        echo "Zombie Process Details:"
        ps aux 2>/dev/null | awk 'NR==1 || $8 ~ /Z/'
    fi
}

# Function to get processes by user
getProcessesByUser() {
    echo "Processes by User (Top 5 Users):"
    ps aux 2>/dev/null | \
        awk 'NR>1 {users[$1]++} END {for (u in users) print users[u], u}' | \
        sort -rn | \
        head -5 | \
        awk '{printf "  %-16s %d processes\n", $2, $1}'
}

# Main execution
main() {
    echo "======================================"
    echo "Running Processes Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    echo "--- System Overview ---"
    echo "Total Processes: $(getProcessCount)"
    echo "Load Averages: $(getLoadAverages)"
    echo ""

    echo "--- CPU Usage Summary ---"
    getCPUUsage
    echo ""

    echo "--- Memory Usage Summary ---"
    getMemoryUsage
    echo ""

    echo "--- Top $TOP_COUNT Processes by CPU ---"
    getTopCPUProcesses
    echo ""

    echo "--- Top $TOP_COUNT Processes by Memory ---"
    getTopMemoryProcesses
    echo ""

    echo "--- Zombie Processes ---"
    getZombieProcesses
    echo ""

    echo "--- Process Distribution ---"
    getProcessesByUser
    echo ""

    echo "======================================"
}

# Run main function
main

exit 0
