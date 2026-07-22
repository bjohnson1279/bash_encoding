#!/usr/bin/env sh
# shellcheck disable=SC3040,SC3043,SC3047

# Exit on error, pipe failure
set -eo pipefail

# Error handler trap
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
trap 'echo "An unexpected error occurred at line $LINENO. Exiting." >&2' ERR
fi

# Copy Plex recordings from a network location


if [ -z "${BATS_VERSION:-}" ]; then
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
fi

fi
# Enter your mount path for network share
MNT_SHARE_PATH=""

# Enter mount location on your local machine
LOCAL_SHARE_PATH="/mnt/plex"

# Enter local path where your recordings will be stored
RECORDING_PATH="/path/to/local/recordings"

# Required Available Space in MB, default is 1 GB
REQUIRED_DISK_AMOUNT=1000

# Gets available disk space in Megabytes.
# POSIX-compliant alternative to 'df -BM --output=avail'
# shellcheck disable=SC3001,SC3043,SC3045
# shellcheck disable=SC2120
get_avail_mb() {
    local target_dir="${1:-.}"
    local out_ref="${2:-}"
    local avail

    # Verify the target directory exists first
    if [ ! -d "$target_dir" ]; then
        return 1
    fi

    # df -P -> POSIX standard, reliable output
    # ⚡ Bolt Optimization: Replace awk process with native shell `read` and arithmetic
    # Uses process substitution to avoid pipe subshell, allowing direct variable assignment.
    {
        read -r _
        read -r _ _ _ avail _
    } < <(df -P -- "$target_dir")

    if [ -n "$out_ref" ]; then
        printf -v "$out_ref" "%s" "$(( avail / 1024 ))"
    else
        echo $(( avail / 1024 ))
    fi
        # 🛡️ Sentinel: Validate numeric input to prevent arithmetic expression injection
        case "${avail#-}" in
            ''|*[!0-9]*) echo 0 ;;
            *) echo $(( avail / 1024 )) ;;
        esac
    }
}

# Gets folder size in Megabytes.
# POSIX-compliant alternative to 'du -BM'
# shellcheck disable=SC3001,SC3043,SC3045
get_folder_size_mb() {
    # $1: folder path
    local folder_path="$1"
    local out_ref="${2:-}"
    local size

    # du -sk -> POSIX standard, size in 1K-blocks
    # ⚡ Bolt Optimization: Replace awk process with native shell `read` and arithmetic
    # Uses process substitution to avoid pipe subshell, allowing direct variable assignment.
    {
        read -r size _
    } < <(du -sk -- "$folder_path")

    if [ -n "$out_ref" ]; then
        printf -v "$out_ref" "%s" "$(( size / 1024 ))"
    else
        echo $(( size / 1024 ))
    fi
        # 🛡️ Sentinel: Validate numeric input to prevent arithmetic expression injection
        case "${size#-}" in
            ''|*[!0-9]*) echo 0 ;;
            *) echo $(( size / 1024 )) ;;
        esac
    }
}

# Syncs a folder if there is enough disk space.
folder_sync() {
    # $1: Source folder to copy
    # $2: Required available space in MB to initiate copy

    local src_folder="$1"
    local required_space="$2"

    # Check if source directory exists
    if [ ! -d "$src_folder" ]; then
        printf "Directory '%s' not available.\n" "$src_folder"
        echo "Please ensure the network share is mounted correctly."
        echo "Example for Linux (Debian/Alpine): sudo mount -t cifs //SERVER/SHARE '$MNT_SHARE_PATH' -o username=USER,password=PASS"
        echo "Example for macOS: sudo mount -t smbfs //USER@SERVER/SHARE '$MNT_SHARE_PATH'"
        return 1
    fi

    local avail_mb
    get_avail_mb "." "avail_mb"
    # shellcheck disable=SC2119
    avail_mb="$(get_avail_mb)"
    echo "Available disk space: ${avail_mb}MB"

    if ! [ "$avail_mb" -ge "$required_space" ] 2>/dev/null; then
        printf "Insufficient disk space to start copy from '%s'.\n" "$src_folder"
        echo "Required: ${required_space}MB, Available: ${avail_mb:-Unknown}MB"
        return 1
    fi

    printf "Calculating size of '%s'...\n" "$src_folder"
    local folder_size_mb
    get_folder_size_mb "$src_folder" "folder_size_mb"
    echo "Calculating size of '$src_folder'..."
    folder_size_mb="$(get_folder_size_mb "$src_folder")"
    echo "Source folder size: ${folder_size_mb}MB"

    if ! [ "$avail_mb" -ge "$folder_size_mb" ] 2>/dev/null; then
        printf "Insufficient disk space to copy '%s'.\n" "$src_folder"
        echo "Required: ${folder_size_mb}MB, Available: ${avail_mb}MB"
        return 1
    fi

    printf "Starting copy from '%s' to '%s'...\n" "$src_folder" "$RECORDING_PATH"
    # 🛡️ Sentinel: Avoid -a (archive) flag to prevent preserving malicious device files (-D) or suid bits (-p) from network shares
    rsync -rltvzh --progress -- "$src_folder/" "$RECORDING_PATH"
    echo "Copy complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
# --- Main Script ---

# Check initial disk space
avail_mb=""
get_avail_mb "." "avail_mb"
if ! [ "$avail_mb" -ge "$REQUIRED_DISK_AMOUNT" ] 2>/dev/null; then
    echo "Insufficient disk space to copy recordings. Required: ${REQUIRED_DISK_AMOUNT}MB, Available: ${avail_mb:-Unknown}MB"
    exit 1
fi
if [ -z "${BATS_VERSION:-}" ]; then
    # Check initial disk space
    # shellcheck disable=SC2119
    avail_mb="$(get_avail_mb)"
    if [ -z "$avail_mb" ] || [ "$avail_mb" -lt "$REQUIRED_DISK_AMOUNT" ]; then
        echo "Insufficient disk space to copy recordings. Required: ${REQUIRED_DISK_AMOUNT}MB, Available: ${avail_mb:-Unknown}MB"
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
fi
