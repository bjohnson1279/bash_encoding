#!/bin/bash

# Exit on error, pipe failure
set -eo pipefail

# Error handler trap
trap 'echo "An unexpected error occurred at line $LINENO. Exiting." >&2' ERR

# Copy Plex recordings from a network location

clear

# Dependency check
for cmd in rsync awk df du mount.cifs; do
    # For mount.cifs, it might not be in the standard PATH for non-root users, so check /sbin explicitly
    if ! command -v "$cmd" >/dev/null 2>&1 && [ ! -x "/sbin/$cmd" ] && [ ! -x "/usr/sbin/$cmd" ]; then
        echo "Error: Required command '$cmd' is not installed." >&2
        if [ "$cmd" = "mount.cifs" ]; then
            echo "  Please install cifs-utils (e.g., 'sudo apk add cifs-utils' on Alpine or 'sudo apt install cifs-utils' on Debian)." >&2
        fi
        exit 1
    fi
done

# Enter your mount path for network share
MNT_SHARE_PATH=""

# Enter mount location on your local machine
LOCAL_SHARE_PATH=""

# Enter local path where your recordings will be stored
RECORDING_PATH=""

# Required Available Space in MB, default is 1 GB
REQUIRED_DISK_AMOUNT=1000

# Gets available disk space in Megabytes.
# POSIX-compliant alternative to 'df -BM --output=avail'
get_avail_mb() {
    local target_dir="${1:-.}"
    # Verify the target directory exists first
    if [ ! -d "$target_dir" ]; then
        return 1
    fi
    # df -P -> POSIX standard, reliable output
    # awk -> extract the available space (4th column), convert from 1K-blocks to MB
    df -P -- "$target_dir" | awk 'NR==2 { print int($4 / 1024) }'
}

# Gets folder size in Megabytes.
# POSIX-compliant alternative to 'du -BM'
get_folder_size_mb() {
    # $1: folder path
    # du -sk -> POSIX standard, size in 1K-blocks
    # awk -> extract the size, convert from 1K-blocks to MB
    du -sk -- "$1" | awk '{ print int($1 / 1024) }'
}

# Getting available disk space
AVAIL=$(get_avail_mb)
AVAIL_MB=${AVAIL//[!0-9]/}

# Output available disk space if you'd like, comment out if not
echo "$AVAIL"

if [ $AVAIL_MB -lt $REQUIRED_DISK_AMOUNT ]; then
    echo "Insufficient disk space to copy recordings"
    exit
fi

folderSync() {
    # $1 => Mounted source of folder to copy
    # $2 => Default size in MB of required available space to copy

    # Check if directory exists
    if [ -d "$1" ]; then
        # Get space available on local hard drive
        AVAIL=$(get_avail_mb)
        AVAIL_MB=${AVAIL//[!0-9]/}

        if [ $AVAIL_MB -lt $2 ]; then
            echo "Insufficient disk space to copy recordings from ${1}"
        else
            echo "Copying from $1"
            FOLDER_SIZE=`du -sh -BM -- "$1"`
            FOLDER_SIZE="${FOLDER_SIZE//$1}"
            FOLDER_SIZE_MB=${FOLDER_SIZE//[!0-9]/}
            echo "Actual Folder Size in MB: $FOLDER_SIZE_MB"
            if [ $AVAIL_MB -lt $FOLDER_SIZE_MB ]; then
                echo "Insufficient disk space to copy recordings from $1"
            else
                rsync -avzh --progress -- "$1" "$RECORDING_PATH"
            fi
        fi
    else
        echo "Directory $1 currently not available"
    fi
}

RECORDINGS_SRC="$LOCAL_SHARE_PATH/Recorded TV Shows"
echo "Recordings Source: $RECORDINGS_SRC"

# Enter mounted location of folder to copy
# Example: If I am copying recordings of Seinfeld from a network location, enter the mounted location as follows
# SEINFELD_SRC="$RECORDINGS_SRC/Seinfeld (1989)"
COPY_FOLDER_SRC="$RECORDINGS_SRC/"

# Enter amount of space in MB required to copy to local folder
# Example: Enter the typical size of the network folder when recordings have just completed
#   If the Seinfeld recordings folder is typically around 2.5G after completion, enter that amount in MB below
# SEINFELD_REQ=2500
COPY_FOLDER_REQ=2500

# Mount Network Location
# Mac users should be able to comment out if network location already mounted
if [ ! -d "$COPY_FOLDER_SRC" ]; then
    sudo mount -t drvfs "$MNT_SHARE_PATH" "$LOCAL_SHARE_PATH"
fi

# Call the folderSync() function, passing the folder location and default MB required to copy to your local hard drive
folderSync "$COPY_FOLDER_SRC" "$COPY_FOLDER_REQ"

# For additional folders to copy, repeat the call to folderSync() function with location and required disk space for each folder to copy
