#!/bin/bash
#
#purpose: Output display info: resolution, model, connection type
#date: January 2026
#

# Constants
SCRIPT_NAME="getDisplayInfo"
SYSTEM_PROFILER="/usr/sbin/system_profiler"

# Function to get display information from system_profiler
getDisplayData() {
    "$SYSTEM_PROFILER" SPDisplaysDataType 2>/dev/null
}

# Function to parse and display graphics card info
getGraphicsCardInfo() {
    local displayData="$1"

    echo "--- Graphics Cards ---"
    echo ""

    # Extract graphics card info
    local cardName
    local chipset
    local vram
    local vendor
    local deviceID
    local metalSupport

    cardName=$(echo "$displayData" | awk -F': ' '/Chipset Model:/ {print $2}' | head -1)
    chipset=$(echo "$displayData" | awk -F': ' '/Type:/ {print $2}' | head -1)
    vram=$(echo "$displayData" | awk -F': ' '/VRAM/ {print $2}' | head -1)
    vendor=$(echo "$displayData" | awk -F': ' '/Vendor:/ {print $2}' | head -1)
    deviceID=$(echo "$displayData" | awk -F': ' '/Device ID:/ {print $2}' | head -1)
    metalSupport=$(echo "$displayData" | awk -F': ' '/Metal Support:/ {print $2}' | head -1)

    echo "Graphics Card: ${cardName:-Unknown}"
    echo "Type: ${chipset:-Unknown}"
    echo "Vendor: ${vendor:-Unknown}"
    echo "VRAM: ${vram:-Unknown}"
    echo "Device ID: ${deviceID:-Unknown}"
    echo "Metal Support: ${metalSupport:-Unknown}"
}

# Function to get connected display info
getConnectedDisplays() {
    local displayData="$1"

    echo "--- Connected Displays ---"
    echo ""

    # Count displays
    local displayCount
    displayCount=$(echo "$displayData" | grep -c "Resolution:")
    echo "Number of Displays: ${displayCount:-0}"
    echo ""

    # Use awk to parse display information blocks
    echo "$displayData" | awk '
    BEGIN { displayNum = 0 }

    # Match display name (lines without colon that are not empty and not indented with many spaces)
    /^        [A-Za-z]/ && !/:/ && !/Displays:/ && !/Graphics/ {
        if (displayNum > 0) print ""
        displayNum++
        gsub(/^[ \t]+/, "", $0)
        print "Display " displayNum ": " $0
    }

    # Match resolution
    /Resolution:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match UI Looks like
    /UI Looks like:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match refresh rate
    /Refresh Rate:/ || /Variable Refresh Rate:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match main display
    /Main Display:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match mirror status
    /Mirror:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match online status
    /Online:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match rotation
    /Rotation:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match connection type
    /Connection Type:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match display type
    /Display Type:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match serial number
    /Display Serial Number:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match display asleep
    /Display Asleep:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }

    # Match ambient brightness
    /Automatically Adjust Brightness:/ {
        gsub(/^[ \t]+/, "", $0)
        print "  " $0
    }
    '
}

# Function to get built-in display info (for MacBooks)
getBuiltInDisplayInfo() {
    local displayData="$1"

    # Check for built-in display
    local builtInDisplay
    builtInDisplay=$(echo "$displayData" | grep -i "built-in" | head -1)

    if [[ -n "$builtInDisplay" ]]; then
        echo ""
        echo "--- Built-in Display ---"

        # Extract built-in display specific info
        local retina
        retina=$(echo "$displayData" | awk -F': ' '/Retina:/ {print $2}' | head -1)

        if [[ -n "$retina" ]]; then
            echo "Retina Display: $retina"
        fi

        # Check for True Tone
        local trueTone
        trueTone=$(echo "$displayData" | awk -F': ' '/True Tone:/ {print $2}' | head -1)

        if [[ -n "$trueTone" ]]; then
            echo "True Tone: $trueTone"
        fi

        # Check for P3 support
        local p3Support
        p3Support=$(echo "$displayData" | grep -i "P3" | head -1)

        if [[ -n "$p3Support" ]]; then
            echo "Wide Color (P3): Supported"
        fi
    fi
}

# Function to get display resolution using screen capture
getCurrentResolution() {
    local resolution
    resolution=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Resolution:/ {print $2}' | head -1)
    echo "${resolution:-Unknown}"
}

# Function to check Night Shift status
getNightShiftStatus() {
    local corebrightness
    corebrightness=$(defaults read com.apple.CoreBrightness.plist 2>/dev/null)

    if [[ -n "$corebrightness" ]]; then
        echo "Night Shift: Configuration exists"
    else
        echo "Night Shift: Unable to determine status"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Display Information Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    # Get all display data
    local displayData
    displayData=$(getDisplayData)

    if [[ -z "$displayData" ]]; then
        echo "Error: Unable to retrieve display information"
        exit 1
    fi

    # Output graphics card info
    getGraphicsCardInfo "$displayData"
    echo ""

    # Output connected displays
    getConnectedDisplays "$displayData"

    # Output built-in display info
    getBuiltInDisplayInfo "$displayData"
    echo ""

    echo "======================================"
}

# Run main function
main

exit 0
