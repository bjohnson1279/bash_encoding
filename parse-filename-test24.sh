#!/usr/bin/env sh

# POSIX-compliant script to parse TV show filenames.
# Handles patterns like "Show.Name.S01E02.Episode.Title.mkv"

parse_filename() {
    if [ -z "$1" ]; then
        echo "Usage: parse_filename \"<filename>\""
        return 1
    fi

    # Remove directory path and file extension
    local base_name="${1##*/}"
    base_name="${base_name%.*}"

    # Use bash regex to capture parts of the filename.
    # The pattern looks for "S<season>E<episode>" and captures the parts around it.
    # It handles variations in separators (., _, -, space).
    local parsed=""
    if [[ "$base_name" =~ ^(.*)[._\ -][Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})(.*)$ ]]; then
        parsed="${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
    elif [[ "$base_name" =~ ^(.*)[._\ -]([0-9]{4})[._\ -]([0-9]{1,2})[._\ -]([0-9]{1,2})(.*)$ ]]; then
        parsed="${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
    fi

    if [ -z "$parsed" ]; then
        echo "Error: Could not parse season/episode from '$base_name'." >&2
        return 1
    fi

    # Use IFS to split the parsed string into variables
    local old_ifs=$IFS
    IFS="|"
    set -f # Temporarily disable globbing to prevent issues with filenames
    set -- $parsed
    set +f # Re-enable globbing
    IFS=$old_ifs

    local show_name="$1"
    show_name="${show_name//[._]/ }"
    show_name="${show_name#"${show_name%%[! ]*}"}"
    show_name="${show_name%"${show_name##*[! ]}"}"

    local season_num="${2#"${2%%[!0]*}"}" # Remove leading zeros
    local episode_num="${3#"${3%%[!0]*}"}" # Remove leading zeros

    local episode_title="$4"
    episode_title="${episode_title//[._]/ }"
    episode_title="${episode_title#"${episode_title%%[! ]*}"}"
    episode_title="${episode_title%"${episode_title##*[! ]}"}"

    # Set variables for caller if this script is sourced
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        PARSED_SHOW_NAME="$show_name"
        PARSED_SEASON_NUM="$season_num"
        PARSED_EPISODE_NUM="$episode_num"
        PARSED_EPISODE_TITLE="$episode_title"

        # Don't output JSON unless it was explicitly expected.
        # Looking at encode-all.sh, it sources parse-filename.sh but never executes `parse_filename` by calling it in a subshell,
        # Wait, encode-all.sh contains this block:
        #    if ! parse_filename "$ts_file"; then
        #        echo "Warning: Could not parse metadata from '$ts_file'. Skipping."
        #        continue
        #    fi
        # But wait, it also calls parseFilename later for something else. `parseFilename "${i}" episode_data`
        # But `parse_filename` is the one from `parse-filename.sh`.
        # The original output was JSON. Let's output JSON regardless. Wait, the original `parse_filename` ALWAYS outputs JSON via `cat <<EOF`.
        # Let's check `test_parse_filename.sh`: it does `output=$(parse_filename "$filename")`. So it needs the JSON output.
    fi

    # Output JSON directly via printf for speed
    printf '{\n  "show_name": "%s",\n  "season": "%s",\n  "episode": "%s",\n  "title": "%s"\n}\n' \
        "${show_name//\"/\\\"}" "$season_num" "$episode_num" "${episode_title//\"/\\\"}"

    return 0
}

# If the script is executed directly, parse the first argument
if [ "parse-filename.sh" = "${0##*/}" ]; then
    parse_filename "$1"
fi
