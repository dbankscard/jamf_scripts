#!/bin/bash

#########################################################################################
# Script Name:  setUserPicture.sh
# Purpose:      Set user profile picture
# Date:         January 2026
#
# Jamf Parameters:
#   $4 = username (required)
#   $5 = picture path or URL (required)
#########################################################################################

#########################################################################################
# VARIABLES
#########################################################################################

# Jamf script parameters
USERNAME="$4"
PICTURE_SOURCE="$5"

# Constants
LOG_FILE="/var/log/jamf_user_management.log"
TEMP_DIR="/tmp/user_pictures"
VALID_EXTENSIONS=("jpg" "jpeg" "png" "tif" "tiff" "gif")

#########################################################################################
# FUNCTIONS
#########################################################################################

logMessage() {
    local message="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${timestamp}: ${message}" | tee -a "${LOG_FILE}"
}

validateParameters() {
    if [[ -z "${USERNAME}" ]]; then
        logMessage "ERROR: Username parameter (\$4) is required"
        exit 1
    fi

    if [[ -z "${PICTURE_SOURCE}" ]]; then
        logMessage "ERROR: Picture path or URL parameter (\$5) is required"
        exit 1
    fi
}

checkUserExists() {
    if ! dscl . -read "/Users/${USERNAME}" &>/dev/null; then
        logMessage "ERROR: User '${USERNAME}' does not exist"
        exit 1
    fi
}

isURL() {
    local source="$1"
    if [[ "${source}" =~ ^https?:// ]]; then
        return 0
    fi
    return 1
}

isValidImageExtension() {
    local file="$1"
    local extension="${file##*.}"
    extension=$(echo "${extension}" | tr '[:upper:]' '[:lower:]')

    for ext in "${VALID_EXTENSIONS[@]}"; do
        if [[ "${extension}" == "${ext}" ]]; then
            return 0
        fi
    done
    return 1
}

downloadPicture() {
    local url="$1"
    local outputFile="$2"

    logMessage "Downloading picture from: ${url}"

    if curl -sL --fail --max-time 30 -o "${outputFile}" "${url}"; then
        logMessage "Successfully downloaded picture"
        return 0
    else
        logMessage "ERROR: Failed to download picture from URL"
        return 1
    fi
}

convertToJPEG() {
    local inputFile="$1"
    local outputFile="$2"

    logMessage "Converting image to JPEG format"

    if sips -s format jpeg "${inputFile}" --out "${outputFile}" &>/dev/null; then
        logMessage "Successfully converted image"
        return 0
    else
        logMessage "ERROR: Failed to convert image"
        return 1
    fi
}

resizeImage() {
    local imageFile="$1"
    local maxSize=512

    # Get current dimensions
    local width height
    width=$(sips -g pixelWidth "${imageFile}" 2>/dev/null | awk '/pixelWidth/{print $2}')
    height=$(sips -g pixelHeight "${imageFile}" 2>/dev/null | awk '/pixelHeight/{print $2}')

    if [[ "${width}" -gt "${maxSize}" ]] || [[ "${height}" -gt "${maxSize}" ]]; then
        logMessage "Resizing image from ${width}x${height} to max ${maxSize}px"
        sips -Z "${maxSize}" "${imageFile}" &>/dev/null
    fi
}

setUserPicture() {
    local username="$1"
    local picturePath="$2"
    local userPictureDir="/Library/User Pictures"
    local destinationPath="${userPictureDir}/${username}.jpg"
    local userHome
    local dsclPicturePath

    userHome=$(dscl . -read "/Users/${username}" NFSHomeDirectory | awk '{print $2}')

    # Ensure User Pictures directory exists
    mkdir -p "${userPictureDir}"

    # Copy picture to standard location
    cp "${picturePath}" "${destinationPath}"
    chmod 644 "${destinationPath}"

    logMessage "Setting profile picture for ${username}"

    # Method 1: Using dscl to set JPEGPhoto attribute
    # Convert to base64 and set
    local pictureData
    pictureData=$(base64 < "${destinationPath}")

    # Delete existing picture attribute
    dscl . -delete "/Users/${username}" JPEGPhoto 2>/dev/null
    dscl . -delete "/Users/${username}" Picture 2>/dev/null

    # Set new picture using dsimport format
    # Create a temporary dsimport file
    local dsimportFile="/tmp/user_picture_import.txt"
    local userRecordName
    local userGUID

    userGUID=$(dscl . -read "/Users/${username}" GeneratedUID | awk '{print $2}')

    # Alternative method: Set Picture attribute to file path
    dscl . -create "/Users/${username}" Picture "${destinationPath}"

    # Method 2: Copy to user's Library for certain macOS versions
    local userLibraryImages="${userHome}/Library/Images"
    mkdir -p "${userLibraryImages}"
    cp "${destinationPath}" "${userLibraryImages}/${username}.jpg"
    chown -R "${username}:staff" "${userLibraryImages}"

    # Method 3: Use system preferences database (for newer macOS)
    local accountsDB="/var/db/dslocal/nodes/Default/users/${username}.plist"
    if [[ -f "${accountsDB}" ]]; then
        # Read image as hex data for plist
        local hexData
        hexData=$(xxd -p "${destinationPath}" | tr -d '\n')

        # Use PlistBuddy to set the picture
        /usr/libexec/PlistBuddy -c "Delete :jpegphoto" "${accountsDB}" 2>/dev/null
        /usr/libexec/PlistBuddy -c "Add :jpegphoto array" "${accountsDB}" 2>/dev/null
        /usr/libexec/PlistBuddy -c "Add :jpegphoto:0 data $(cat "${destinationPath}" | base64)" "${accountsDB}" 2>/dev/null
    fi

    logMessage "Profile picture set for ${username}"
    return 0
}

cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

#########################################################################################
# MAIN SCRIPT
#########################################################################################

logMessage "========== Starting setUserPicture.sh =========="

# Check if running as root
if [[ "$(id -u)" -ne 0 ]]; then
    logMessage "ERROR: This script must be run as root"
    exit 1
fi

# Validate parameters
validateParameters

# Check if user exists
checkUserExists

# Create temp directory
mkdir -p "${TEMP_DIR}"
trap cleanup EXIT

# Determine if source is URL or local path
picturePath=""

if isURL "${PICTURE_SOURCE}"; then
    # Download from URL
    downloadedFile="${TEMP_DIR}/downloaded_picture"
    if ! downloadPicture "${PICTURE_SOURCE}" "${downloadedFile}"; then
        exit 1
    fi
    picturePath="${downloadedFile}"
else
    # Use local path
    if [[ ! -f "${PICTURE_SOURCE}" ]]; then
        logMessage "ERROR: Picture file not found: ${PICTURE_SOURCE}"
        exit 1
    fi
    picturePath="${PICTURE_SOURCE}"
fi

# Verify it's an image file
if ! file "${picturePath}" | grep -qiE "image|bitmap|jpeg|png|gif|tiff"; then
    logMessage "ERROR: File does not appear to be a valid image"
    exit 1
fi

# Convert to JPEG if needed
jpegFile="${TEMP_DIR}/${USERNAME}_picture.jpg"
if ! convertToJPEG "${picturePath}" "${jpegFile}"; then
    logMessage "WARNING: Could not convert image, using original"
    jpegFile="${picturePath}"
fi

# Resize if necessary
resizeImage "${jpegFile}"

# Set the user picture
if setUserPicture "${USERNAME}" "${jpegFile}"; then
    logMessage "Script completed successfully"
    exit 0
else
    logMessage "Script failed"
    exit 1
fi
