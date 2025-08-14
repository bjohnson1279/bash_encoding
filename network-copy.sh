#!/usr/bin/env sh

# Copy Plex recordings from a network location

# --- Configuration ---
# Enter your mount path for network share (used for mounting instructions)
MNT_SHARE_PATH="/mnt/plex"

# Enter mount location on your local machine
LOCAL_SHARE_PATH="/mnt/plex"

# Enter local path where your recordings will be stored
RECORDING_PATH="/path/to/local/recordings"

# Required Available Space in MB, default is 1 GB
REQUIRED_DISK_AMOUNT=1000

# --- Functions ---

# Gets available disk space in Megabytes.
# POSIX-compliant alternative to 'df -BM --output=avail'
get_avail_mb() {
    # df -P . -> POSIX standard, reliable output
    # awk -> extract the available space (4th column), convert from 1K-blocks to MB
    df -P . | awk 'NR==2 { print int($4 / 1024) }'
}

# Gets folder size in Megabytes.
# POSIX-compliant alternative to 'du -BM'
get_folder_size_mb() {
    # $1: folder path
    # du -sk -> POSIX standard, size in 1K-blocks
    # awk -> extract the size, convert from 1K-blocks to MB
    du -sk "$1" | awk '{ print int($1 / 1024) }'
}

# Syncs a folder if there is enough disk space.
folder_sync() {
    # $1: Source folder to copy
    # $2: Required available space in MB to initiate copy

    local src_folder="$1"
    local required_space="$2"

    # Check if source directory exists
    if [ ! -d "$src_folder" ]; then
        echo "Directory '$src_folder' not available."
        echo "Please ensure the network share is mounted correctly."
        echo "Example for Linux (Debian/Alpine): sudo mount -t cifs //SERVER/SHARE '$MNT_SHARE_PATH' -o username=USER,password=PASS"
        echo "Example for macOS: sudo mount -t smbfs //USER@SERVER/SHARE '$MNT_SHARE_PATH'"
        return 1
    fi

    local avail_mb=$(get_avail_mb)
    echo "Available disk space: ${avail_mb}MB"

    if [ "$avail_mb" -lt "$required_space" ]; then
        echo "Insufficient disk space to start copy from '$src_folder'."
        echo "Required: ${required_space}MB, Available: ${avail_mb}MB"
        return 1
    fi

    echo "Calculating size of '$src_folder'..."
    local folder_size_mb=$(get_folder_size_mb "$src_folder")
    echo "Source folder size: ${folder_size_mb}MB"

    if [ "$avail_mb" -lt "$folder_size_mb" ]; then
        echo "Insufficient disk space to copy '$src_folder'."
        echo "Required: ${folder_size_mb}MB, Available: ${avail_mb}MB"
        return 1
    fi

    echo "Starting copy from '$src_folder' to '$RECORDING_PATH'..."
    rsync -avzh --progress "$src_folder/" "$RECORDING_PATH"
    echo "Copy complete."
}

# --- Main Script ---

# Check initial disk space
avail_mb=$(get_avail_mb)
if [ "$avail_mb" -lt "$REQUIRED_DISK_AMOUNT" ]; then
    echo "Insufficient disk space to copy recordings. Required: ${REQUIRED_DISK_AMOUNT}MB, Available: ${avail_mb}MB"
    exit 1
fi

# --- Define Folders to Copy ---
# Add more calls to folder_sync for each show or directory you want to copy.

# Example 1: Copying a specific TV show
# ------------------------------------------
# Source directory on the mounted share
# recordings_src="$LOCAL_SHARE_PATH/Recorded TV Shows/Seinfeld (1989)"
# Required disk space in MB to check before starting
# required_space_seinfeld=2500
# folder_sync "$recordings_src" "$required_space_seinfeld"

# Example 2: Copying the entire recordings directory
# ------------------------------------------
recordings_src_all="$LOCAL_SHARE_PATH/Recorded TV Shows"
required_space_all=5000 # 5 GB
folder_sync "$recordings_src_all" "$required_space_all"

# Example 3: Another show
# ------------------------------------------
# recordings_src_another="$LOCAL_SHARE_PATH/Recorded TV Shows/Another Show (2022)"
# required_space_another=3000
# folder_sync "$recordings_src_another" "$required_space_another"
