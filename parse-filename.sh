#!/bin/bash

# POSIX-compliant script to parse TV show filenames.
# Handles patterns like "Show.Name.S01E02.Episode.Title.mkv"

# Cleans up a string by replacing dots and underscores with spaces,
# and trimming leading/trailing whitespace.
# Note: This function is deprecated in favor of native bash substitutions for performance,
# but kept here to maintain backward compatibility for tests or other scripts using it.
cleanup_name() {
    local str="$1"
    str="${str//[._]/ }"
    # Trim leading/trailing whitespace natively
    shopt -s extglob 2>/dev/null || true
    str="${str##*( )}"
    str="${str%%*( )}"
    shopt -u extglob 2>/dev/null || true
    echo "$str"
}

# Escapes a string for use in JSON.
# Note: This function is deprecated in favor of native bash substitutions for performance,
# but kept here to maintain backward compatibility.
json_escape() {
    local str="$1"
    str="${str//\"/\\\"}"
    echo "$str"
}

parse_filename() {
    if [ -z "$1" ]; then
        echo "Usage: parse_filename \"<filename>\""
        return 1
    fi

    # Remove directory path and file extension using bash parameter expansion
    local base_name="${1##*/}"
    base_name="${base_name%.*}"

    local show_name season_num episode_num episode_title

    # Use bash regex to capture parts of the filename instead of spawning sed
    # Pattern looks for "S<season>E<episode>" and captures the parts around it.
    if [[ "$base_name" =~ ^(.*)[._\ -][Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})(.*)$ ]]; then
        show_name="${BASH_REMATCH[1]}"
        season_num="${BASH_REMATCH[2]}"
        episode_num="${BASH_REMATCH[3]}"
        episode_title="${BASH_REMATCH[4]}"

        # If show_name ends with a separator, remove it
        if [[ "$show_name" =~ ^(.*)[._\ -]$ ]]; then
            show_name="${BASH_REMATCH[1]}"
        fi
    elif [[ "$base_name" =~ ^(.*)[._\ -]([0-9]{4})[._\ -]([0-9]{1,2})[._\ -]([0-9]{1,2})(.*)$ ]]; then
        # Fallback for filenames with the date as episode "Show.Name.2023.10.27.mkv"
        show_name="${BASH_REMATCH[1]}"
        season_num="${BASH_REMATCH[2]}"
        episode_num="${BASH_REMATCH[3]}"
        episode_title="${BASH_REMATCH[4]}"

        # If show_name ends with a separator, remove it
        if [[ "$show_name" =~ ^(.*)[._\ -]$ ]]; then
            show_name="${BASH_REMATCH[1]}"
        fi
    else
        echo "Error: Could not parse season/episode from '$base_name'." >&2
        return 1
    fi

    # Instead of calling subshells `$(cleanup_name ...)`, do it purely with native
    # bash parameter expansion inline here to avoid the performance overhead
    # of spawning subshells in tight loops.

    # Clean up names natively
    show_name="${show_name//[._]/ }"
    episode_title="${episode_title//[._]/ }"

    # Trim leading/trailing whitespace natively
    shopt -s extglob
    show_name="${show_name##*( )}"
    show_name="${show_name%%*( )}"
    episode_title="${episode_title##*( )}"
    episode_title="${episode_title%%*( )}"
    shopt -u extglob

    # Ensure two digit zero padding for backward compatibility formatting
    # First removing leading zeros to prevent octal interpretation
    season_stripped="${season_num#"${season_num%%[!0]*}"}"
    episode_stripped="${episode_num#"${episode_num%%[!0]*}"}"
    # If it was "0" or "00", stripped is empty. Default to 0.
    season_stripped="${season_stripped:-0}"
    episode_stripped="${episode_stripped:-0}"

    printf -v season_num "%02d" "$season_stripped"
    printf -v episode_num "%02d" "$episode_stripped"

    # Escape quotes for JSON inline natively
    show_name="${show_name//\"/\\\"}"
    episode_title="${episode_title//\"/\\\"}"

    # Output JSON using printf instead of spawning cat and subshells
    printf '{\n  "show_name": "%s",\n  "season": "%s",\n  "episode": "%s",\n  "title": "%s"\n}\n' \
        "$show_name" "$season_num" "$episode_num" "$episode_title"

    return 0
}

# If the script is executed directly, parse the first argument
if [ "parse-filename.sh" = "${0##*/}" ]; then
    parse_filename "$1"
fi
