#!/bin/bash
#
#purpose: List all applications in /Applications with version numbers
#date: January 2026
#

# Constants
SCRIPT_NAME="getInstalledApps"
APPLICATIONS_DIR="/Applications"
SYSTEM_APPLICATIONS_DIR="/System/Applications"

# Function to get app version from Info.plist
getAppVersion() {
    local appPath="$1"
    local plistPath="${appPath}/Contents/Info.plist"
    local version=""

    if [[ -f "$plistPath" ]]; then
        version=$(/usr/bin/defaults read "$plistPath" CFBundleShortVersionString 2>/dev/null)
        if [[ -z "$version" ]]; then
            version=$(/usr/bin/defaults read "$plistPath" CFBundleVersion 2>/dev/null)
        fi
    fi

    echo "${version:-Unknown}"
}

# Function to get app bundle identifier
getAppBundleID() {
    local appPath="$1"
    local plistPath="${appPath}/Contents/Info.plist"
    local bundleID=""

    if [[ -f "$plistPath" ]]; then
        bundleID=$(/usr/bin/defaults read "$plistPath" CFBundleIdentifier 2>/dev/null)
    fi

    echo "${bundleID:-Unknown}"
}

# Function to list applications in a directory
listApplications() {
    local directory="$1"
    local appCount=0

    if [[ ! -d "$directory" ]]; then
        echo "Directory not found: $directory"
        return 1
    fi

    while IFS= read -r -d '' appPath; do
        local appName
        local appVersion
        local bundleID

        appName=$(basename "$appPath" .app)
        appVersion=$(getAppVersion "$appPath")
        bundleID=$(getAppBundleID "$appPath")

        printf "%-40s | Version: %-15s | Bundle ID: %s\n" "$appName" "$appVersion" "$bundleID"
        ((appCount++))
    done < <(find "$directory" -maxdepth 1 -name "*.app" -print0 2>/dev/null | sort -z)

    echo ""
    echo "Total: $appCount applications"
}

# Function to count total applications
countApplications() {
    local userApps
    local systemApps

    userApps=$(find "$APPLICATIONS_DIR" -maxdepth 1 -name "*.app" 2>/dev/null | wc -l | tr -d ' ')
    systemApps=$(find "$SYSTEM_APPLICATIONS_DIR" -maxdepth 1 -name "*.app" 2>/dev/null | wc -l | tr -d ' ')

    echo "User Applications: $userApps"
    echo "System Applications: $systemApps"
    echo "Total: $((userApps + systemApps))"
}

# Main execution
main() {
    echo "======================================"
    echo "Installed Applications Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    echo "--- Applications Summary ---"
    countApplications
    echo ""

    echo "--- User Applications ($APPLICATIONS_DIR) ---"
    echo ""
    listApplications "$APPLICATIONS_DIR"
    echo ""

    echo "--- System Applications ($SYSTEM_APPLICATIONS_DIR) ---"
    echo ""
    listApplications "$SYSTEM_APPLICATIONS_DIR"
    echo ""

    echo "======================================"
}

# Run main function
main

exit 0
