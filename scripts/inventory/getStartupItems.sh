#!/bin/bash
#
#purpose: List login items and launch agents/daemons
#date: January 2026
#

# Constants
SCRIPT_NAME="getStartupItems"
CURRENT_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(dscl . -read /Users/"$CURRENT_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')

# Launch agent/daemon paths
SYSTEM_LAUNCH_DAEMONS="/Library/LaunchDaemons"
SYSTEM_LAUNCH_AGENTS="/Library/LaunchAgents"
USER_LAUNCH_AGENTS="${USER_HOME}/Library/LaunchAgents"
APPLE_LAUNCH_DAEMONS="/System/Library/LaunchDaemons"
APPLE_LAUNCH_AGENTS="/System/Library/LaunchAgents"

# Function to get current user's login items
getLoginItems() {
    local loginItems

    # Use osascript to get login items from System Events
    loginItems=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null)

    if [[ -n "$loginItems" && "$loginItems" != "" ]]; then
        # Convert comma-separated to newlines
        echo "$loginItems" | tr ',' '\n' | sed 's/^[ \t]*//' | while read -r item; do
            if [[ -n "$item" ]]; then
                echo "  - $item"
            fi
        done
    else
        echo "  No login items configured for current user"
    fi
}

# Function to list launch items in a directory
listLaunchItems() {
    local directory="$1"
    local itemType="$2"
    local itemCount=0

    if [[ ! -d "$directory" ]]; then
        echo "  Directory not found: $directory"
        return 1
    fi

    # Find all plist files
    while IFS= read -r plistFile; do
        if [[ -f "$plistFile" ]]; then
            local label
            local program
            local runAtLoad
            local keepAlive
            local disabled

            # Extract label from plist
            label=$(/usr/bin/defaults read "${plistFile%.plist}" Label 2>/dev/null)

            if [[ -z "$label" ]]; then
                label=$(basename "$plistFile" .plist)
            fi

            # Get program/program arguments
            program=$(/usr/bin/defaults read "${plistFile%.plist}" Program 2>/dev/null)
            if [[ -z "$program" ]]; then
                program=$(/usr/bin/defaults read "${plistFile%.plist}" ProgramArguments 2>/dev/null | head -2 | tail -1 | tr -d '[:space:]",')
            fi

            # Check if it runs at load
            runAtLoad=$(/usr/bin/defaults read "${plistFile%.plist}" RunAtLoad 2>/dev/null)

            # Check if disabled
            disabled=$(/usr/bin/defaults read "${plistFile%.plist}" Disabled 2>/dev/null)

            # Check status using launchctl
            local status="Unknown"
            if [[ "$itemType" == "daemon" ]]; then
                if launchctl list 2>/dev/null | grep -q "$label"; then
                    status="Loaded"
                else
                    status="Not Loaded"
                fi
            else
                if launchctl list 2>/dev/null | grep -q "$label"; then
                    status="Loaded"
                else
                    status="Not Loaded"
                fi
            fi

            # Mark if disabled
            if [[ "$disabled" == "1" ]]; then
                status="Disabled"
            fi

            echo "  Label: $label"
            echo "    Status: $status"
            if [[ -n "$program" ]]; then
                echo "    Program: $program"
            fi
            if [[ "$runAtLoad" == "1" ]]; then
                echo "    Run at Load: Yes"
            fi
            echo ""

            ((itemCount++))
        fi
    done < <(find "$directory" -maxdepth 1 -name "*.plist" 2>/dev/null | sort)

    if [[ "$itemCount" -eq 0 ]]; then
        echo "  No items found"
    fi

    echo "  Total: $itemCount items"
}

# Function to count items in directory
countLaunchItems() {
    local directory="$1"

    if [[ ! -d "$directory" ]]; then
        echo "0"
        return
    fi

    find "$directory" -maxdepth 1 -name "*.plist" 2>/dev/null | wc -l | tr -d ' '
}

# Function to list loaded launch services
getLoadedServices() {
    local serviceType="$1"

    case "$serviceType" in
        "system")
            launchctl list 2>/dev/null | awk 'NR>1 {print $3}' | grep -v "^-$" | sort | head -20
            ;;
        "user")
            launchctl list 2>/dev/null | awk 'NR>1 {print $3}' | grep -v "^-$" | sort | head -20
            ;;
    esac
}

# Function to check for third-party kernel extensions
getKernelExtensions() {
    local kextDir="/Library/Extensions"
    local kextCount=0

    if [[ -d "$kextDir" ]]; then
        while IFS= read -r kext; do
            if [[ -d "$kext" ]]; then
                local kextName
                local kextVersion

                kextName=$(basename "$kext" .kext)
                kextVersion=$(/usr/bin/defaults read "$kext/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)

                echo "  - $kextName (Version: ${kextVersion:-Unknown})"
                ((kextCount++))
            fi
        done < <(find "$kextDir" -maxdepth 1 -name "*.kext" 2>/dev/null | sort)
    fi

    if [[ "$kextCount" -eq 0 ]]; then
        echo "  No third-party kernel extensions found"
    else
        echo ""
        echo "  Total: $kextCount kernel extensions"
    fi
}

# Function to list cron jobs
getCronJobs() {
    local cronJobs

    # Check user crontab
    cronJobs=$(crontab -l 2>/dev/null)

    if [[ -n "$cronJobs" ]]; then
        echo "User Cron Jobs ($CURRENT_USER):"
        echo "$cronJobs" | while read -r line; do
            if [[ -n "$line" && ! "$line" =~ ^# ]]; then
                echo "  $line"
            fi
        done
    else
        echo "  No user cron jobs configured"
    fi

    # Check system cron directories
    echo ""
    echo "System Cron Directories:"
    for cronDir in /etc/cron.d /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        if [[ -d "$cronDir" ]]; then
            local fileCount
            fileCount=$(ls -1 "$cronDir" 2>/dev/null | wc -l | tr -d ' ')
            echo "  $cronDir: $fileCount items"
        fi
    done
}

# Main execution
main() {
    echo "======================================"
    echo "Startup Items Report"
    echo "Generated: $(date)"
    echo "Current User: $CURRENT_USER"
    echo "======================================"
    echo ""

    echo "--- Summary ---"
    echo "System Launch Daemons: $(countLaunchItems "$SYSTEM_LAUNCH_DAEMONS")"
    echo "System Launch Agents: $(countLaunchItems "$SYSTEM_LAUNCH_AGENTS")"
    echo "User Launch Agents: $(countLaunchItems "$USER_LAUNCH_AGENTS")"
    echo ""

    echo "--- Login Items (Current User) ---"
    getLoginItems
    echo ""

    echo "--- System Launch Daemons ($SYSTEM_LAUNCH_DAEMONS) ---"
    echo ""
    listLaunchItems "$SYSTEM_LAUNCH_DAEMONS" "daemon"
    echo ""

    echo "--- System Launch Agents ($SYSTEM_LAUNCH_AGENTS) ---"
    echo ""
    listLaunchItems "$SYSTEM_LAUNCH_AGENTS" "agent"
    echo ""

    echo "--- User Launch Agents ($USER_LAUNCH_AGENTS) ---"
    echo ""
    listLaunchItems "$USER_LAUNCH_AGENTS" "agent"
    echo ""

    echo "--- Third-Party Kernel Extensions ---"
    getKernelExtensions
    echo ""

    echo "--- Cron Jobs ---"
    getCronJobs
    echo ""

    echo "======================================"
}

# Run main function
main

exit 0
