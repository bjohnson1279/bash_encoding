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

# --- Script's own path ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PARSE_SCRIPT_PATH="$SCRIPT_DIR/parse-filename.sh"

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

# Sources the parsing function from the external script.
source_parser() {
    if [ ! -f "$PARSE_SCRIPT_PATH" ]; then
        echo "Error: The parser script was not found at '$PARSE_SCRIPT_PATH'." >&2
        exit 1
    fi
    # Source the script to make the parse_filename function available
    # shellcheck source=./parse-filename.sh
    source "$PARSE_SCRIPT_PATH"
}

# Gets the duration of a video in seconds.
# Uses ffprobe for more reliable and direct output.
get_duration() {
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

# --- Main Script ---

# Ensure dependencies are met before starting
check_dependencies
source_parser

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
find "$RECORDING_PATH" -type f -name "*.ts" -print0 | while IFS= read -r -d $'\0' ts_file; do
    echo "--------------------------------------------------"
    echo "Processing file: $ts_file"

    # Parse filename to get metadata
    # This function is from the sourced parse-filename.sh script.
    # It returns a status code and sets PARSED_* variables.
    if ! parse_filename "$ts_file"; then
        echo "Warning: Could not parse metadata from '$ts_file'. Skipping."
        continue
    fi

    show_name="$PARSED_SHOW_NAME"
    season="$PARSED_SEASON_NUM"
    episode="$PARSED_EPISODE_NUM"
    title="$PARSED_EPISODE_TITLE"

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

    # --- Pre-flight check on the source file ---
    echo "Verifying source file integrity with ffprobe..."
    if ! ffprobe -v error "$ts_file" >/dev/null 2>&1; then
        echo "Error: Source file '$ts_file' appears to be corrupt or unreadable by ffprobe. Skipping."
        continue
    fi


    # Construct ffmpeg command using a bash array for safety and clarity
    ffmpeg_args=(
        -i "$ts_file"
        -c:v "$ENC_TYPE" -c:a copy -pix_fmt yuv420p
    )
    if [ -n "$VF" ]; then
        ffmpeg_args+=(-vf "$VF")
    fi
    ffmpeg_args+=(
        -preset "$PRESET" -crf "$QUALITY"
        -metadata "show=$show_name"
        -metadata "season_number=$season"
        -metadata "episode_sort=$episode"
        -metadata "title=$title"
    )

    # Execute the command
    echo "Encoding..."
    # We redirect stderr (2) to stdout (1), then pipe it to `tee`.
    # `tee` will print to the console and also write to the log file.
    # We use `pipefail` to ensure the exit status of the `if` statement
    # is from ffmpeg, not from tee.
    set -o pipefail
    if ! ffmpeg "${ffmpeg_args[@]}" "$new_file_full" 2>&1 | tee "${new_file_full}.log"; then
        echo "Error: Encoding failed. See log for details: ${new_file_full}.log"
        set +o pipefail # Unset pipefail
        continue # Move to the next file
    fi
    set +o pipefail # Unset pipefail

    # Verify encoding and optionally delete original
    if [ -f "$new_file_full" ]; then
        src_duration=$(get_duration "$ts_file")
        dest_duration=$(get_duration "$new_file_full")

        # Compare durations (allowing for small floating point differences)
        duration_diff=$(echo "d = $src_duration - $dest_duration; if (d < 0) d = -d; d" | bc)

        if (( $(echo "$duration_diff < 1.0" | bc -l) )); then
            echo "Encoding successful. Durations match."
            if [ "$DEL_ORIG" -eq 1 ]; then
                echo "Deleting original file: $ts_file"
                rm "$ts_file"
            fi
        else
            echo "Warning: Duration mismatch. Source: ${src_duration}s, Dest: ${dest_duration}s. Original file kept."
        fi
    else
        # This case should now be caught by the ! ffmpeg ... check above, but we leave it as a safeguard.
        echo "Error: Encoding failed. Output file not found. See log for details: ${new_file_full}.log"
    fi
done

echo "--------------------------------------------------"
echo "All processing complete."
