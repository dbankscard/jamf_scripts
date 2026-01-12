#!/bin/bash
#
#purpose: List all configured printers with driver info
#date: January 2026
#

# Constants
SCRIPT_NAME="getPrinterList"
LPSTAT="/usr/bin/lpstat"
LPOPTIONS="/usr/bin/lpoptions"

# Function to get list of printers
getPrinterList() {
    local printerList
    printerList=$("$LPSTAT" -p 2>/dev/null)

    if [[ -z "$printerList" ]]; then
        return 1
    fi

    echo "$printerList" | awk '/^printer/ {print $2}'
}

# Function to get default printer
getDefaultPrinter() {
    local defaultPrinter
    defaultPrinter=$("$LPSTAT" -d 2>/dev/null | awk -F': ' '{print $2}')
    echo "${defaultPrinter:-None configured}"
}

# Function to get printer details
getPrinterDetails() {
    local printerName="$1"

    if [[ -z "$printerName" ]]; then
        return 1
    fi

    # Get printer status
    local printerStatus
    printerStatus=$("$LPSTAT" -p "$printerName" 2>/dev/null | awk '{$1=$2=""; print $0}' | sed 's/^[ \t]*//')

    # Get printer options which includes driver info
    local printerOptions
    printerOptions=$("$LPOPTIONS" -p "$printerName" -l 2>/dev/null)

    # Get device URI
    local deviceURI
    deviceURI=$("$LPSTAT" -v "$printerName" 2>/dev/null | awk -F': ' '{print $2}')

    # Get printer description from lpstat
    local printerDescription
    printerDescription=$(lpstat -l -p "$printerName" 2>/dev/null | awk '/Description:/ {$1=""; print $0}' | sed 's/^[ \t]*//')

    # Get driver info from system_profiler
    local driverInfo
    driverInfo=$(/usr/sbin/system_profiler SPPrintersDataType 2>/dev/null | \
        awk -v printer="$printerName" '
            $0 ~ printer {found=1}
            found && /Driver Version:/ {print $0; exit}
        ' | awk -F': ' '{print $2}')

    # Get PPD file location
    local ppdFile="/etc/cups/ppd/${printerName}.ppd"
    local ppdDriver=""
    if [[ -f "$ppdFile" ]]; then
        ppdDriver=$(grep "^\*NickName:" "$ppdFile" 2>/dev/null | cut -d'"' -f2)
    fi

    echo "  Printer Name: $printerName"
    echo "  Status: ${printerStatus:-Unknown}"
    echo "  Device URI: ${deviceURI:-Unknown}"
    echo "  Description: ${printerDescription:-None}"
    echo "  Driver: ${ppdDriver:-Unknown}"
    echo "  Driver Version: ${driverInfo:-Unknown}"
}

# Function to get printer connection type
getConnectionType() {
    local uri="$1"

    case "$uri" in
        *usb*)
            echo "USB"
            ;;
        *ipp://* | *ipps://*)
            echo "IPP (Network)"
            ;;
        *socket://* | *lpd://*)
            echo "Network Socket"
            ;;
        *smb://*)
            echo "SMB (Windows Shared)"
            ;;
        *dnssd://*)
            echo "Bonjour/AirPrint"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Function to get printer status from CUPS
getPrinterCUPSStatus() {
    local printerName="$1"
    local accepting
    local enabled

    # Check if printer is accepting jobs
    accepting=$("$LPSTAT" -a "$printerName" 2>/dev/null | awk '{print $NF}')

    # Check if printer is enabled
    enabled=$("$LPSTAT" -p "$printerName" 2>/dev/null)

    if [[ "$enabled" == *"idle"* ]]; then
        echo "Idle"
    elif [[ "$enabled" == *"printing"* ]]; then
        echo "Printing"
    elif [[ "$enabled" == *"disabled"* ]]; then
        echo "Disabled"
    else
        echo "Unknown"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Printer List Report"
    echo "Generated: $(date)"
    echo "======================================"
    echo ""

    # Get default printer
    echo "--- Default Printer ---"
    echo "Default: $(getDefaultPrinter)"
    echo ""

    # Get list of all printers
    local printers
    printers=$(getPrinterList)

    if [[ -z "$printers" ]]; then
        echo "No printers configured on this system"
        echo "======================================"
        exit 0
    fi

    # Count printers
    local printerCount
    printerCount=$(echo "$printers" | wc -l | tr -d ' ')
    echo "--- Configured Printers ($printerCount total) ---"
    echo ""

    # Get details for each printer
    while IFS= read -r printer; do
        if [[ -n "$printer" ]]; then
            getPrinterDetails "$printer"

            # Get device URI for connection type
            local deviceURI
            deviceURI=$("$LPSTAT" -v "$printer" 2>/dev/null | awk -F': ' '{print $2}')
            echo "  Connection Type: $(getConnectionType "$deviceURI")"
            echo "  CUPS Status: $(getPrinterCUPSStatus "$printer")"
            echo ""
        fi
    done <<< "$printers"

    echo "======================================"
}

# Run main function
main

exit 0
