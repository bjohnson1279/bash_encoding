#!/usr/bin/env bash

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

# Function to obtain length of video
getDuration() {
    local dur format_dur stream_dur output

    # ⚡ Bolt Optimization: Fetch both format and stream durations in a single ffprobe call.
    # This halves process spawning overhead for files missing format duration (or returning N/A).
    output=$(ffprobe -v error -select_streams v:0 -show_entries format=duration:stream=duration -of flat -i "${1}" 2>/dev/null || true)

    if [[ "$output" =~ format\.duration=\"([^\"]+)\" ]]; then
        format_dur="${BASH_REMATCH[1]}"
    fi
    if [[ "$output" =~ streams\.stream\.0\.duration=\"([^\"]+)\" ]]; then
        stream_dur="${BASH_REMATCH[1]}"
    fi

    if [ -n "$format_dur" ] && [ "$format_dur" != "N/A" ]; then
        dur="$format_dur"
    elif [ -n "$stream_dur" ] && [ "$stream_dur" != "N/A" ]; then
        dur="$stream_dur"
    fi

    # ⚡ Bolt Optimization: Support nameref for direct variable assignment, avoiding subshells
    if [[ -n "$2" ]]; then
        if [[ ! "$2" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Error: Invalid output variable name." >&2
            return 1
        fi
        local -n out_var="$2"
        out_var="${dur}"
    else
        printf '%s\n' "${dur}"
    fi
}

# Extract Part of File Name Into JSON String To Use As Metadata
# Utility functions for parsing
cleanup_name() {
    local val="${1//[._]/ }"
    local out_ref_name="$2"

    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"

    if [ -n "$out_ref_name" ]; then
        if [[ ! "$out_ref_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Error: Invalid output variable name." >&2
            return 1
        fi
        printf -v "$out_ref_name" "%s" "$val"
    else
        printf '%s\n' "$val"
    fi
}

json_escape() {
    local val="$1"
    local out_ref_name="$2"

    local escaped="${val//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//$'\n'/\\n}"

    if [ -n "$out_ref_name" ]; then
        if [[ ! "$out_ref_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Error: Invalid output variable name." >&2
            return 1
        fi
        printf -v "$out_ref_name" "%s" "$escaped"
    else
        printf '%s\n' "$escaped"
    fi
}

parseFilename() {
    # $1 => File Name
    local base_name="${1%.ts}"
    
    local show_raw=""
    local season_raw=""
    local episode_raw=""
    local title_raw=""
    local year_raw=""

    # 1. Try to match: Show Name (Year) - S01E02 - Title (Date Time)
    if [[ "$base_name" =~ ^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]+(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$ ]]; then
        show_raw="${BASH_REMATCH[1]}"
        year_raw="${BASH_REMATCH[2]}"
        season_raw="${BASH_REMATCH[3]}"
        episode_raw="${BASH_REMATCH[4]}"
        title_raw="${BASH_REMATCH[5]}"
    # 2. Try to match: Show Name (Year) S01E02 Title (Date Time)
    elif [[ "$base_name" =~ ^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]+(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$ ]]; then
        show_raw="${BASH_REMATCH[1]}"
        year_raw="${BASH_REMATCH[2]}"
        season_raw="${BASH_REMATCH[3]}"
        episode_raw="${BASH_REMATCH[4]}"
        title_raw="${BASH_REMATCH[5]}"
    # 3. Try to match: Show Name (Year) S01E02 Title...
    elif [[ "$base_name" =~ ^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]*(.*)$ ]]; then
        show_raw="${BASH_REMATCH[1]}"
        year_raw="${BASH_REMATCH[2]}"
        season_raw="${BASH_REMATCH[3]}"
        episode_raw="${BASH_REMATCH[4]}"
        title_raw="${BASH_REMATCH[5]}"
        # Strip trailing date if present
        if [[ "$title_raw" =~ ^(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$ ]]; then
            title_raw="${BASH_REMATCH[1]}"
        fi
    # 4. Try to match: Movie Name (Year)
    elif [[ "$base_name" =~ ^(.*)\ \(([0-9]{4})\)$ ]]; then
        show_raw="${BASH_REMATCH[1]}"
        year_raw="${BASH_REMATCH[2]}"
    else
        # Fallback basic matching
        if [[ "$base_name" =~ ^(.*)[._\ -][Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})(.*)$ ]]; then
            show_raw="${BASH_REMATCH[1]}"
            season_raw="${BASH_REMATCH[2]}"
            episode_raw="${BASH_REMATCH[3]}"
            title_raw="${BASH_REMATCH[4]}"
        fi
    fi

    # Formatting season / episode
    local season_num=""
    local episode_num=""

    if [ -n "$season_raw" ]; then
        local season_stripped="${season_raw#"${season_raw%%[!0]*}"}"
        season_stripped="${season_stripped:-0}"
        if [ ${#season_stripped} -eq 1 ]; then
            season_num="0$season_stripped"
        else
            season_num="$season_stripped"
        fi
    fi

    if [ -n "$episode_raw" ]; then
        local episode_stripped="${episode_raw#"${episode_raw%%[!0]*}"}"
        episode_stripped="${episode_stripped:-0}"
        if [ ${#episode_stripped} -eq 1 ]; then
            episode_num="0$episode_stripped"
        else
            episode_num="$episode_stripped"
        fi
    fi

    local show_name episode_title
    cleanup_name "$show_raw" show_name
    cleanup_name "$title_raw" episode_title

    # ⚡ Bolt Optimization: Set PARSED_* variables for use with --no-json
    PARSED_SHOW_NAME="$show_name"
    PARSED_SEASON_NUM="$season_num"
    PARSED_EPISODE_NUM="$episode_num"
    PARSED_EPISODE_TITLE="$episode_title"


    local esc_show esc_season esc_episode esc_title esc_premiered esc_date
    json_escape "$show_name" esc_show
    json_escape "$season_num" esc_season
    json_escape "$episode_num" esc_episode
    json_escape "$episode_title" esc_title
    json_escape "$year_raw" esc_premiered
    json_escape "" esc_date # We leave date empty for compatibility or further parsing if needed

    local json_str=""
    if [ "$2" != "--no-json" ]; then
        printf -v json_str '{"show":"%s","season":"%s","episode":"%s","title":"%s","premiered":"%s","date":"%s"}' \
            "$esc_show" \
            "$esc_season" \
            "$esc_episode" \
            "$esc_title" \
            "$esc_premiered" \
            "$esc_date"
    fi

    if [[ -n "$2" ]]; then
        if [ "$2" = "--no-json" ]; then return 0; fi
        if [[ ! "$2" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Error: Invalid output variable name." >&2
            return 1
        fi
        local -n out_var="$2"
        out_var="$json_str"
    else
        printf '%s\n' "$json_str"
    fi
}

if [ ! -d "$DESTINATION_PATH" ]; then
    echo "Error: Destination path '$DESTINATION_PATH' not found." >&2
    exit 1
fi

# Use find to locate all .ts files recursively, which is more robust
# than nested loops and `cd`.
shopt -s globstar nullglob
for ts_file in "$RECORDING_PATH"/**/*.ts; do
    shopt -u globstar nullglob
    echo "--------------------------------------------------"
    printf 'Processing file: %s\n' "$ts_file"

    # Parse filename to get metadata
    # This function is from the sourced parse-filename.sh script.
    # It returns a status code and sets PARSED_* variables.
    # ⚡ Bolt Optimization: Pass --no-json to prevent expensive JSON escaping/formatting since we only read PARSED_* variables
    if ! parseFilename "$ts_file" --no-json; then
        echo "Warning: Could not parse metadata from '$ts_file'. Skipping."
        continue
    fi

    show_name="$PARSED_SHOW_NAME"
    season="$PARSED_SEASON_NUM"
    episode="$PARSED_EPISODE_NUM"
    title="$PARSED_EPISODE_TITLE"

    # Create a clean, organized filename
    # ⚡ Bolt Optimization: Replace subshell `$(printf...)` with native bash `printf -v` to avoid process spawning in busy loops
    printf -v new_filename "%s - S%02dE%02d - %s.mp4" "$show_name" "$season" "$episode" "$title"
    # ⚡ Bolt Optimization: Replace subshell and sed with native bash parameter expansion
    # This avoids spawning a new process for each file, improving speed in busy loops
    # Remove any invalid characters for filenames
    new_filename="${new_filename//[\/\\\\?%*:|\"<>]/_}"
    new_file_full="$DESTINATION_PATH/$new_filename"

    printf '  Show: %s\n' "$show_name"
    printf '  Season: %s, Episode: %s\n' "$season" "$episode"
    printf '  Title: %s\n' "$title"
    printf '  Output file: %s\n' "$new_file_full"

    # Skip if the encoded file already exists
    if [ -f "$new_file_full" ]; then
        printf "Warning: Destination file '%s' already exists. Skipping.\n" "$new_file_full"
        continue
    fi

    # --- Pre-flight check on the source file ---
    echo "Verifying source file integrity with ffprobe..."
    # ⚡ Bolt Optimization: Combine pre-flight integrity check and duration fetch into one call.
    # ffprobe will return empty/no duration for corrupt files.
    getDuration "$ts_file" src_duration
    if [ -z "$src_duration" ] || [ "$src_duration" = "N/A" ]; then
        printf "Error: Source file '%s' appears to be corrupt or unreadable by ffprobe. Skipping.\n" "$ts_file"
        continue
    fi


    # Construct ffmpeg command using a bash array for safety and clarity
    ffmpeg_args=(
        -nostdin
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
        printf "Error: Encoding failed. See log for details: %s.log\n" "${new_file_full}"
        set +o pipefail # Unset pipefail
        continue # Move to the next file
    fi
    set +o pipefail # Unset pipefail

    # Verify encoding and optionally delete original
    if [ -f "$new_file_full" ]; then
        # ⚡ Bolt Optimization: Replace subshells with nameref for performance
        getDuration "$new_file_full" dest_duration

        if [ -z "$src_duration" ] || [ "$src_duration" = "N/A" ] || [ -z "$dest_duration" ] || [ "$dest_duration" = "N/A" ]; then
            echo "Warning: Duration could not be reliably determined. Original file kept."
        elif ! [[ "$src_duration" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! [[ "$dest_duration" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            # 🛡️ Sentinel: Validate duration formats to prevent arithmetic expression injection during calculation
            echo "Warning: Duration formats are invalid. Expected numeric formats. Original file kept."
        else
            # ⚡ Bolt Optimization: Replace subshells spawning `bc` with native bash fixed-point math.
            # This avoids expensive process forks, significantly speeding up the duration matching logic.

            # Extract fractional parts and pad to 6 decimal places
            src_frac="${src_duration#*.}"
            [ "$src_frac" = "$src_duration" ] && src_frac=""
            src_frac="${src_frac}000000"
            src_frac="${src_frac:0:6}"

            dest_frac="${dest_duration#*.}"
            [ "$dest_frac" = "$dest_duration" ] && dest_frac=""
            dest_frac="${dest_frac}000000"
            dest_frac="${dest_frac:0:6}"

            # Extract integer parts
            src_int="${src_duration%.*}"
            dest_int="${dest_duration%.*}"

            # Concatenate for fixed-point representation
            src_val="$src_int$src_frac"
            dest_val="$dest_int$dest_frac"

            # Strip leading zeros to avoid octal interpretation, default to 0 if empty
            src_val="${src_val#"${src_val%%[!0]*}"}"
            dest_val="${dest_val#"${dest_val%%[!0]*}"}"
            src_val="${src_val:-0}"
            dest_val="${dest_val:-0}"

            # Calculate absolute difference
            duration_diff=$(( src_val - dest_val ))
            duration_diff="${duration_diff#-}"

            # Compare difference (< 1000000 is < 1.0)
            if [ "$duration_diff" -lt 1000000 ]; then
                echo "Encoding successful. Durations match."
                if [ "$DEL_ORIG" -eq 1 ]; then
                    printf "Deleting original file: %s\n" "$ts_file"
                    rm -- "$ts_file"
                fi
            else
                echo "Warning: Duration mismatch. Source: ${src_duration}s, Dest: ${dest_duration}s. Original file kept."
            fi
        fi
    else
        # This case should now be caught by the ! ffmpeg ... check above, but we leave it as a safeguard.
        printf "Error: Encoding failed. Output file not found. See log for details: %s.log\n" "${new_file_full}"
    fi
done

echo "--------------------------------------------------"
echo "All processing complete."
