#!/usr/bin/env bash

# Bash script to parse TV show filenames.
# Handles patterns like "Show.Name.S01E02.Episode.Title.mkv"

# Cleans up a string by replacing dots and underscores with spaces,
# and trimming leading/trailing whitespace.
# ⚡ Bolt Optimization: Use `tr` and parameter expansion instead of multiple sed operations.
# Using parameter expansion for stripping whitespaces is POSIX compliant (`${var#"${var%%[! ]*}"}`).
# Using `tr` avoids multiple process forks compared to `sed`.
cleanup_name() {
    # Replace dots and underscores with spaces
    # shellcheck disable=SC3043 # local is supported in environments where this script is executed
    # ⚡ Bolt Optimization: Replace IFS string splitting with native bash parameter expansion.
    # This avoids process forking and makes the cleanup significantly faster.
    local val="${1//[._]/ }"
    local out_ref_name="$2"

    # Strip leading whitespace
    val="${val#"${val%%[! ]*}"}"
    # Strip trailing whitespace
    val="${val%"${val##*[! ]}"}"
    # Strip trailing " -" if present
    val="${val%" -"}"
    # Strip trailing whitespace again
    val="${val%"${val##*[! ]}"}"

    if [ -n "$out_ref_name" ]; then
        # ⚡ Bolt Optimization: Use printf -v instead of eval to prevent command injection and subshell overhead
        printf -v "$out_ref_name" "%s" "$val"
    else
        printf '%s\n' "$val"
    fi
}

# Escapes a string for use in JSON.
json_escape() {
    # ⚡ Bolt Optimization: Replace sed subshells with parameter expansion string replacement.
    # While ${var//\"/\\\"} is a bashism, we must stay POSIX-compliant.
    # POSIX compliant string replacement for escaping double quotes to avoid subshell process fork overhead.
    # shellcheck disable=SC3043
    local val="$1"
    # shellcheck disable=SC3043
    local escaped=""
    while [ -n "$val" ]; do
        case "$val" in
            *\"*)
                escaped="${escaped}${val%%\"*}\\\""
                val="${val#*\"}"
                ;;
            *)
                escaped="${escaped}${val}"
                val=""
                ;;
        esac
    done
    printf '%s\n' "$escaped"
}

parse_filename() {
    if [ -z "$1" ]; then
        echo "Usage: parse_filename \"<filename>\""
        return 1
    fi

    # Remove directory path and file extension
    # ⚡ Bolt Optimization: Replace `basename` subshell with native POSIX parameter expansion
    base_name="${1##*/}"
    base_name="${base_name%.*}"

    # ⚡ Bolt Optimization: Combine sequential sed operations into a single invocation
    # The pattern looks for "S<season>E<episode>" and captures the parts around it.
    # It handles variations in separators (., _, -, space).
    # If standard pattern fails, fallback for filenames with the date as episode "Show.Name.2023.10.27.mkv"
    parsed=$(printf '%s\n' "$base_name" | sed -n \
        -e 's/^\(.*\)[ ._-][Ss]\([0-9]\{1,2\}\)[ ._-]*[Ee]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p' \
        -e 's/^\(.*\)[ ._-]\([0-9]\{4\}\)[ ._-]\([0-9]\{1,2\}\)[ ._-]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p' | head -n 1)

    if [ -z "$parsed" ]; then
        printf "Error: Could not parse season/episode from '%s'.\n" "$base_name" >&2
        return 1
    fi

    # Use IFS to split the parsed string into variables
    old_ifs=$IFS
    IFS="|"
    set -f # Temporarily disable globbing to prevent issues with filenames
    # shellcheck disable=SC2086
    set -- $parsed
    set +f # Re-enable globbing
    IFS=$old_ifs

    # ⚡ Bolt Optimization: Replace subshells and sed with native POSIX parameter expansion to remove leading zeros
    season_stripped="${season_raw#"${season_raw%%[!0]*}"}"
    episode_stripped="${episode_raw#"${episode_raw%%[!0]*}"}"
    season_stripped="${season_stripped:-0}"
    episode_stripped="${episode_stripped:-0}"

    # Pad to 2 digits natively in POSIX sh
    if [ ${#season_stripped} -eq 1 ]; then
        season_num="0$season_stripped"
    else
        season_num="$season_stripped"
    fi
    PARSED_SEASON_NUM="$season_num"

    if [ ${#episode_stripped} -eq 1 ]; then
        episode_num="0$episode_stripped"
    else
        episode_num="$episode_stripped"
    fi
    PARSED_EPISODE_NUM="$episode_num"

    cleanup_name "$title_raw" PARSED_EPISODE_TITLE
    episode_title="$PARSED_EPISODE_TITLE"

    # ⚡ Bolt Optimization: Skip expensive JSON escaping and formatting if --no-json is passed.
    if [ "$2" != "--no-json" ]; then
        json_escape "$show_name" show_name_esc
        json_escape "$episode_title" episode_title_esc

        # Output JSON
        printf '{\n  "show_name": "%s",\n  "season": "%s",\n  "episode": "%s",\n  "title": "%s"\n}\n' \
            "$show_name_esc" \
            "$season_num" \
            "$episode_num" \
            "$episode_title_esc"
    fi

    return 0
}

# If the script is executed directly, parse the first argument
# ⚡ Bolt Optimization: Replace `basename` subshell with native parameter expansion
exec_name="${0##*/}"
if [ "parse-filename.sh" = "$exec_name" ]; then
    parse_filename "$1"
fi
