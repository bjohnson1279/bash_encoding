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

# Function to obtain length of video
getDuration() {
    local dur
    dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -i "${1}")
    if [ "${dur}" = "N/A" ] || [ -z "${dur}" ]; then
        dur=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 -i "${1}")
    fi
    printf '%s\n' "${dur}"
}

# Extract Part of File Name Into JSON String To Use As Metadata
parseFilename() {
    # $1 => File Name
    FILE="${1%.ts}"
    
    shopt -s extglob
    SHOW_NAME="$FILE \([0-9]*}"
    SHOW_NAME="${SHOW_NAME% S[0-9]*}"
    SHOW_NAME="${SHOW_NAME##*( )}"
    SHOW_NAME="${SHOW_NAME%%*( )}"
    shopt -u extglob
    # echo "Show Name: '$SHOW_NAME'"
    
    YEAR_PREMIERED=${FILE//${SHOW_NAME} /}
    YEAR_PREMIERED=${YEAR_PREMIERED%\) *}
    YEAR_PREMIERED=${YEAR_PREMIERED//[^0-9]}
    YEAR_PREMIERED=${YEAR_PREMIERED:0:4}
    # echo "Year Premiered: '$YEAR_PREMIERED'"
    
    DATE_TIME=""
    DATE_TIME=${FILE//${SHOW_NAME} /}
    DATE_TIME=${DATE_TIME//\${YEAR_PREMIERED\) /}
    DATE_TIME=${DATE_TIME//- /}
    DATE_TIME=${DATE_TIME%% [A-Z]*}
    DATE_TIME=${DATE_TIME#^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9]}
    shopt -s extglob
    DATE_TIME=${DATE_TIME##*( )}
    DATE_TIME=${DATE_TIME%%*( )}
    shopt -u extglob
    # echo "Date/Time: '$DATE_TIME'"
    
    DATE=""
    DATE=${DATE_TIME// [0-9][0-9] [0-9][0-9] [0-9][0-9]/}
    shopt -s extglob
    DATE=${DATE##*( )}
    DATE=${DATE%%*( )}
    shopt -u extglob
    # echo "Date: '$DATE'"
    
    NUM_DATE=${DATE//-/}
    # echo "Num Date: $NUM_DATE"
    
    YEAR=${DATE:0:4}
    # echo "Year: $YEAR"
    
    TIME=""
    TIME=${DATE_TIME//$DATE/}
    shopt -s extglob
    TIME=${TIME##*( )}
    TIME=${TIME%%*( )}
    # echo "Time: '$TIME'"
    
    # Simply Remaining Data Extraction By Removing From $FILE variable
    FILE=${FILE//${TIME}/}
    FILE=${FILE//${YEAR_PREMIERED}\)/}
    FILE=${FILE//\(stop*/}
    FILE=${FILE//\(start*/}
    
    SEASON=${FILE//${SHOW_NAME} \(/}
    SEASON=${FILE//${SHOW_NAME}/}
    SEASON=${SEASON%E*}
    SEASON=${SEASON//[^0-9]}
    SEASON=${SEASON:0:4}
    # echo "Season: $SEASON"
    
    EPISODE=${FILE//${SHOW_NAME}/}
    EPISODE=${EPISODE//\(${YEAR_PREMIERED}\)/}
    if [ $SEASON == $YEAR ]; then
        EPISODE=${NUM_DATE//${SEASON}/}
    else
        EPISODE=${EPISODE//${TIME}/}
        EPISODE=${EPISODE// S${SEASON}E/}
        EPISODE=${EPISODE//[^0-9]}
    fi
    # echo "Episode: ${EPISODE}"
    
    EPISODE_TITLE=${FILE//${SHOW_NAME} /}
    EPISODE_TITLE=${EPISODE_TITLE//\(${YEAR_PREMIERED}\)/}
    EPISODE_TITLE=${EPISODE_TITLE// \- /}
    EPISODE_TITLE=${EPISODE_TITLE//${TIME}/}
    EPISODE_TITLE=${EPISODE_TITLE//S${SEASON}E${EPISODE}/}
    EPISODE_TITLE=${EPISODE_TITLE%%${SHOW_NAME}}}
    EPISODE_TITLE=${EPISODE_TITLE//\(stop*/}
    EPISODE_TITLE=${EPISODE_TITLE//\(start*/}
    EPISODE_TITLE=${EPISODE_TITLE//\([0-9]*/}
    shopt -s extglob
    EPISODE_TITLE=${EPISODE_TITLE##*( )}
    EPISODE_TITLE=${EPISODE_TITLE%%*( )}
    shopt -u extglob
    # echo "Episode Title: '${EPISODE_TITLE}'"
    
    # ⚡ Bolt Optimization: Use printf and native bash parameter expansion instead of jq subshell
    # This significantly improves performance in busy loops by avoiding process overhead
    local esc_show="${SHOW_NAME//\\/\\\\}"
    esc_show="${esc_show//\"/\\\"}"
    esc_show="${esc_show//$'\n'/\\n}"

    local esc_season="${SEASON//\\/\\\\}"
    esc_season="${esc_season//\"/\\\"}"
    esc_season="${esc_season//$'\n'/\\n}"

    local esc_episode="${EPISODE//\\/\\\\}"
    esc_episode="${esc_episode//\"/\\\"}"
    esc_episode="${esc_episode//$'\n'/\\n}"

    local esc_title="${EPISODE_TITLE//\\/\\\\}"
    esc_title="${esc_title//\"/\\\"}"
    esc_title="${esc_title//$'\n'/\\n}"

    local esc_premiered="${YEAR_PREMIERED//\\/\\\\}"
    esc_premiered="${esc_premiered//\"/\\\"}"
    esc_premiered="${esc_premiered//$'\n'/\\n}"

    local esc_date="${DATE//\\/\\\\}"
    esc_date="${esc_date//\"/\\\"}"
    esc_date="${esc_date//$'\n'/\\n}"

    # ⚡ Bolt Optimization: Accept a nameref (reference to a variable) as an optional argument.
    # If the second argument is provided, write the JSON string directly into that variable.
    # Otherwise, fallback to echo to maintain backward compatibility (e.g., for tests).
    # This eliminates subshell overhead `$(parseFilename ...)` when used in busy loops.
    local json_str
    printf -v json_str '{"show":"%s","season":"%s","episode":"%s","title":"%s","premiered":"%s","date":"%s"}' \
        "$esc_show" \
        "$esc_season" \
        "$esc_episode" \
        "$esc_title" \
        "$esc_premiered" \
        "$esc_date"

    if [[ -n "$2" ]]; then
        local -n out_var="$2"
        out_var="$json_str"
    else
        printf '%s\n' "$json_str"
    fi
}

if [ -d "$RECORDING_PATH" ]; then
    cd -- "$RECORDING_PATH" || continue
    shopt -s nullglob dotglob
    files=(*)
    file_count=${#files[@]}
    shopt -u nullglob dotglob
    if [ $file_count != 0 ]; then
        # Iterate through all directories in folder containing your recordings
        for dir in */; do
            printf '%s\n' "${dir}"

            # Validate directory exists, in case folder was deleted after list was obtained
            if [ -d "${dir}" ]; then
                cd -- "${dir}" || continue

                # Get number of folders in directory (Seasons)
                shopt -s nullglob dotglob
                dir_files=(*)
                dir_file_count=${#dir_files[@]}
                shopt -u nullglob dotglob
                echo "$dir directory file count: ${dir_file_count}"

                if [ $dir_file_count != 0 ]; then
                    # Iterate through Season folders
                    for season in */; do
                        printf '%s\n' "${season}"
                        if [ -d "${season}" ]; then
                            cd -- "${season}" || continue
                            
                            # Get number of .ts files found in Season directory
                            shopt -s nullglob
                            ts_files=(*.ts)
                            ts_dir_file_count=${#ts_files[@]}
                            shopt -u nullglob
                            echo "${season} ts file count: ${ts_dir_file_count}"

                            if [ $ts_dir_file_count != 0 ]; then
                                for i in *.ts; do
                                    printf '%s\n' "${i}"

                                    # ⚡ Bolt Optimization: Pass 'episode_data' as a nameref instead of using a subshell `episode_data=$(...)`.
                                    # Spawning subshells in a busy loop carries a large overhead; namerefs skip the subshell entirely.
                                    parseFilename "${i}" episode_data
                                    echo "Episode Data: ${episode_data}"
                                    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
                                        SHOW_NAME="${BASH_REMATCH[1]}"
                                        SHOW_NAME="${SHOW_NAME//\\\"/\"}"
                                    else
                                        SHOW_NAME=""
                                    fi

                                    # Apply pattern matching to remove extraneous data in file name
                                    # Removes year, dashes, and adds space between season and episode number
                                    shopt -s extglob
                                    new_file=${i//\(*\) /}}
                                    new_file=${new_file//- /}}

                                    # ⚡ Bolt Optimization: Replace subshell and sed with native bash parameter expansion
                                    # This avoids spawning a new process for each file, significantly improving speed in busy loops
                                    for j in {0..9}; do
                                        new_file="${new_file//${j}E/${j} E}"
                                    done

                                    new_file=${new_file// [0-9][0-9] [0-9][0-9] [0-9][0-9]/}
                                    new_file=${new_file%.*}

                                    # Remove the second occurrence of the show name
                                    first_part="${new_file%%"$SHOW_NAME"*}"
                                    rest="${new_file#*"$SHOW_NAME"}"
                                    if [[ "$rest" == *"$SHOW_NAME"* ]]; then
                                        second_part="${rest%%"$SHOW_NAME"*}"
                                        third_part="${rest#*"$SHOW_NAME"}"
                                        new_file="${first_part}${SHOW_NAME}${second_part}${third_part}"
                                    fi
                                    new_file=${new_file##*( )}
                                    new_file=${new_file%%*( )}
echo "New File: ${new_file}"
                                    new_file_full="${DESTINATION_PATH}${new_file}.mp4"

                                    # Validate existience of file
                                    if [ -f "$i" ]; then
                                        # Skip if encoded file already exists, encode if not
                                        if [ ! -f "$new_file_full" ]; then
                                            # Check for optional video filter
                                            if [ $VF != "" ]; then
                                                ffmpeg -i "$i" \
                                                    -vf $VF \
                                                    -c:v $ENC_TYPE -c:a copy \
                                                    -pix_fmt yuv420p \
                                                    -tune film \
                                                    -movflags faststart \
                                                    -metadata show="$SHOW_NAME" \
                                                    -preset $PRESET \
                                                    -crf $QUALITY \
                                                    "${new_file_full}"
                                            else
                                                ffmpeg -i "${i}" \
                                                    -c:v $ENC_TYPE -c:a copy \
                                                    -pix_fmt yuv420p \
                                                    -tune film \
                                                    -movflags faststart \
                                                    -metadata show="$SHOW_NAME" \
                                                    -preset $PRESET \
                                                    -crf $QUALITY \
                                                    "${new_file_full}"
                                            fi
                                        fi

                                        # OPTIONAL: Delete source (ts) file when new file (mp4) is created, for space saving purposes
                                        # Set DEL_ORIG value to 0 above if you don't want this to happen
                                        if [ $DEL_ORIG == 1 ]; then
                                            # Get video duration of encoding source
                                            src_duration=$(getDuration "${i}")
                                            src_duration="${src_duration%.*}"

                                            dest_duration=$(getDuration "$new_file_full")
                                            dest_duration="${dest_duration%.*}"
                                            echo "dest_duration: $dest_duration"

                                            echo "Source File Duration: $src_duration"
                                            echo "Destination File Duration: $dest_duration"

                                            if [ -n "$src_duration" ] && [ "$src_duration" != "N/A" ] && [ "$src_duration" == "$dest_duration" ]; then
                                                rm -- "$i"
                                            fi
                                        fi
                                    fi
                                    shopt -u extglob
                                done # END for loop for ts files in directory
                            fi

                            # Done with directory, go one up to move on to next
                            cd ..
                        fi
                    done # END for loop for Season directories
                fi

                # Go back to recording path to move on to the next show
                cd -- "$RECORDING_PATH"
            fi
        done # END for loop for all TV show directories
    fi
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
    # ⚡ Bolt Optimization: Replace subshell and sed with native bash parameter expansion
    # This avoids spawning a new process for each file, improving speed in busy loops
    # Remove any invalid characters for filenames
    new_filename="${new_filename//[\/\\\\?%*:|\"<>]/_}"
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
    if ! ffprobe -v error -i "$ts_file" >/dev/null 2>&1; then
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
        src_duration=$(getDuration "$ts_file")
        dest_duration=$(getDuration "$new_file_full")

        if [ -z "$src_duration" ] || [ "$src_duration" = "N/A" ] || [ -z "$dest_duration" ] || [ "$dest_duration" = "N/A" ]; then
            echo "Warning: Duration could not be reliably determined. Original file kept."
        else
            # Compare durations (allowing for small floating point differences)
            duration_diff=$(echo "d = $src_duration - $dest_duration; if (d < 0) d = -d; d" | bc)

            if (( $(echo "$duration_diff < 1.0" | bc -l) )); then
                echo "Encoding successful. Durations match."
                if [ "$DEL_ORIG" -eq 1 ]; then
                    echo "Deleting original file: $ts_file"
                    rm -- "$ts_file"
                fi
            else
                echo "Warning: Duration mismatch. Source: ${src_duration}s, Dest: ${dest_duration}s. Original file kept."
            fi
        fi
    else
        # This case should now be caught by the ! ffmpeg ... check above, but we leave it as a safeguard.
        echo "Error: Encoding failed. Output file not found. See log for details: ${new_file_full}.log"
    fi
done

echo "--------------------------------------------------"
echo "All processing complete."
