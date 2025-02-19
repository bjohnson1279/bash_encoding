#!/bin/bash

# Copy Plex recordings from a network location

clear

# Enter your mount path for network share
MNT_SHARE_PATH=""

# Enter mount location on your local machine
LOCAL_SHARE_PATH=""

# Enter local path where your recordings will be stored
RECORDING_PATH=""

# Required Available Space in MB, default is 1 GB
REQUIRED_DISK_AMOUNT=1000

getAvailMB() {
    df -h /mnt/d -BM --output=avail | sed /Avail/d
}

folderSize() {
    # $1 folder path
    du -sh "$1" -BM
}

# Getting available disk space
AVAIL=$(getAvailMB)
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
        AVAIL=$(getAvailMB)
        AVAIL_MB=${AVAIL//[!0-9]/}

        if [ $AVAIL_MB -lt $2 ]; then
            echo "Insufficient disk space to copy recordings from ${1}"
        else
            echo "Copying from $1"
            FOLDER_SIZE=`du -sh "$1" -BM`
            FOLDER_SIZE="${FOLDER_SIZE//$1}"
            FOLDER_SIZE_MB=${FOLDER_SIZE//[!0-9]/}
            echo "Actual Folder Size in MB: $FOLDER_SIZE_MB"
            if [ $AVAIL_MB -lt $FOLDER_SIZE_MB ]; then
                echo "Insufficient disk space to copy recordings from $1"
            else
                rsync -avzh --progress "$1" "$RECORDING_PATH"
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
