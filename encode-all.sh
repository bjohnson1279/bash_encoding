#!/usr/bin/env sh

# --- Configuration ---
# Location of the local folder where Plex recordings are stored
RECORDING_PATH="/path/to/recordings"
# Location where encoded files will be stored
DESTINATION_PATH="/path/to/encoded"
# FFMPEG encoder to be used
ENC_TYPE="libx264"
# Video filters applied, default is yadif for deinterlacing
VF="yadif"
# Speed of encoding process, default is veryslow for smaller file sizes
PRESET="veryslow"
# Quality level, default is 21
QUALITY=21
# Delete original file after encoding? (1 for YES, 0 for NO)
DEL_ORIG=1

# --- Function Definitions ---

# Checks for required command-line tools.
check_dependencies() {
    for cmd in ffmpeg ffprobe jq bc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Required command '$cmd' is not installed." >&2
            exit 1
        fi
    done
}

# Gets the duration of a video in seconds.
# Uses ffprobe for more reliable and direct output.
get_duration() {
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

# --- Main Script ---

# Ensure dependencies are met before starting
check_dependencies

# Validate paths
if [ ! -d "$RECORDING_PATH" ]; then
    echo "Error: Recording path '$RECORDING_PATH' not found." >&2
    exit 1
fi
if [ ! -d "$DESTINATION_PATH" ]; then
    echo "Error: Destination path '$DESTINATION_PATH' not found." >&2
    exit 1
fi

# Use find to locate all .ts files recursively, which is more robust
# than nested loops and `cd`.
find "$RECORDING_PATH" -type f -name "*.ts" | while read -r ts_file; do
    echo "--------------------------------------------------"
    echo "Processing file: $ts_file"

    # Parse filename to get metadata
    # The 'parse-filename.sh' script must be in the same directory or in the system's PATH
    episode_data=$(sh parse-filename.sh "$ts_file")
    if [ $? -ne 0 ]; then
        echo "Warning: Could not parse metadata from '$ts_file'. Skipping."
        continue
    fi

    show_name=$(echo "$episode_data" | jq -r '.show_name')
    season=$(echo "$episode_data" | jq -r '.season')
    episode=$(echo "$episode_data" | jq -r '.episode')
    title=$(echo "$episode_data" | jq -r '.title')

    # Create a clean, organized filename
    new_filename=$(printf "%s - S%02dE%02d - %s.mp4" "$show_name" "$season" "$episode" "$title")
    # Remove any invalid characters for filenames
    new_filename=$(echo "$new_filename" | sed 's/[/\\?%*:|"<>]/_/g')
    new_file_full="$DESTINATION_PATH/$new_filename"

    echo "  Show: $show_name"
    echo "  Season: $season, Episode: $episode"
    echo "  Title: $title"
    echo "  Output file: $new_file_full"

    # Skip if the encoded file already exists
    if [ -f "$new_file_full" ]; then
        echo "Warning: Destination file '$new_file_full' already exists. Skipping."
        continue
    fi

    # Construct ffmpeg command
    ffmpeg_cmd="ffmpeg -i \"$ts_file\" -c:v $ENC_TYPE -c:a copy -pix_fmt yuv420p"
    if [ -n "$VF" ]; then
        ffmpeg_cmd="$ffmpeg_cmd -vf $VF"
    fi
    ffmpeg_cmd="$ffmpeg_cmd -preset $PRESET -crf $QUALITY"
    ffmpeg_cmd="$ffmpeg_cmd -metadata show=\"$show_name\" -metadata season=\"$season\" -metadata episode=\"$episode\" -metadata title=\"$title\""
    ffmpeg_cmd="$ffmpeg_cmd \"$new_file_full\""

    # Execute the command
    echo "Encoding..."
    eval "$ffmpeg_cmd"

    # Verify encoding and optionally delete original
    if [ -f "$new_file_full" ]; then
        src_duration=$(get_duration "$ts_file")
        dest_duration=$(get_duration "$new_file_full")

        # Compare durations (allowing for small floating point differences)
        duration_diff=$(echo "$src_duration - $dest_duration" | bc | awk '{print ($1 > 0) ? $1 : -$1}')

        if [ $(echo "$duration_diff < 1.0" | bc) -eq 1 ]; then
            echo "Encoding successful. Durations match."
            if [ "$DEL_ORIG" -eq 1 ]; then
                echo "Deleting original file: $ts_file"
                rm "$ts_file"
            fi
        else
            echo "Warning: Duration mismatch. Source: ${src_duration}s, Dest: ${dest_duration}s. Original file kept."
        fi
    else
        echo "Error: Encoding failed. Output file not found."
    fi
done

echo "--------------------------------------------------"
echo "All processing complete."
