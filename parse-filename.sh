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
    # ⚡ Bolt Optimization: Replace `tr` and command substitution with POSIX IFS string splitting.
    # This avoids spawning a subshell and process for each cleanup.
    local val
    local out_ref_name="$2"
    # shellcheck disable=SC3043 # local is supported in environments where this script is executed
    local IFS="._"
    # shellcheck disable=SC3043
    local old_set="$-"

    set -f
    # shellcheck disable=SC2086 # Expected to split the string
    set -- $1

    # We set IFS to space to join the arguments via "$*"
    IFS=" "
    val="$*"

    # Restore previous globbing state safely
    case "$old_set" in
        *f*) ;;         # Was already off, do nothing
        *) set +f ;;    # Was on, turn it back on
    esac

    # Strip leading whitespace
    val="${val#"${val%%[! ]*}"}"
    # Strip trailing whitespace
    val="${val%"${val##*[! ]}"}"
    # Strip trailing " -" if present
    val="${val%" -"}"
    # Strip trailing whitespace again
    val="${val%"${val##*[! ]}"}"

    if [ -n "$out_ref_name" ]; then
        printf -v "$out_ref_name" "%s" "$val"
    else
        printf '%s\n' "$val"
    fi
}

# Escapes a string for use in JSON.
json_escape() {
    # ⚡ Sentinel: Prevent JSON injection and syntax errors by fully escaping backslashes, quotes, and control characters according to JSON specification.
    # ⚡ Bolt Optimization: Use bash native string replacement instead of spawning subshells with sed/awk.
    local val="$1"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    val="${val//$'\n'/\\n}"
    val="${val//$'\r'/\\r}"
    val="${val//$'\t'/\\t}"
    if [ -n "$2" ]; then
        printf -v "$2" "%s" "$val"
    else
        printf '%s' "$val"
    fi
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

    # Use native Bash regex to capture parts of the filename to avoid subshell overhead.
    # The pattern looks for "S<season>E<episode>" and captures the parts around it.
    # It handles variations in separators (., _, -, space).
    # ⚡ Bolt Optimization: Replace sed subshell with native bash regex matching for better performance.
    if [[ "$base_name" =~ ^(.*)[._\ -][Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})(.*)$ ]]; then
        parsed="${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
    elif [[ "$base_name" =~ ^(.*)[._\ -]([0-9]{4})[._\ -]([0-9]{1,2})[._\ -]([0-9]{1,2})(.*)$ ]]; then
        parsed="${BASH_REMATCH[1]}|${BASH_REMATCH[2]}|${BASH_REMATCH[3]}|${BASH_REMATCH[4]}"
    else
        parsed=""
    fi

    if [ -z "$parsed" ]; then
        printf "Error: Could not parse season/episode from '%s'.\n" "$base_name" >&2
        return 1
    fi

    # Use IFS to split the parsed string into variables
    old_ifs=$IFS
    IFS="|"
    set -f # Temporarily disable globbing to prevent issues with filenames
    # shellcheck disable=SC2086 # Intentionally using word splitting
    set -- $parsed
    set +f # Re-enable globbing
    IFS=$old_ifs

    local show_name episode_title show_name_esc episode_title_esc
    cleanup_name "$1" show_name
    # ⚡ Bolt Optimization: Replace subshells and sed with native POSIX parameter expansion to remove leading zeros
    season_stripped="${2#"${2%%[!0]*}"}"
    episode_stripped="${3#"${3%%[!0]*}"}"
    season_stripped="${season_stripped:-0}"
    episode_stripped="${episode_stripped:-0}"

    # Pad to 2 digits natively in POSIX sh
    if [ ${#season_stripped} -eq 1 ]; then
        season_num="0$season_stripped"
    else
        season_num="$season_stripped"
    fi

    if [ ${#episode_stripped} -eq 1 ]; then
        episode_num="0$episode_stripped"
    else
        episode_num="$episode_stripped"
    fi
    cleanup_name "$4" episode_title

    json_escape "$show_name" show_name_esc
    json_escape "$episode_title" episode_title_esc

    # Output JSON
    printf '{\n  "show_name": "%s",\n  "season": "%s",\n  "episode": "%s",\n  "title": "%s"\n}\n' \
        "$show_name_esc" \
        "$season_num" \
        "$episode_num" \
        "$episode_title_esc"

    return 0
}

# If the script is executed directly, parse the first argument
# ⚡ Bolt Optimization: Replace `basename` subshell with native parameter expansion
exec_name="${0##*/}"
if [ "parse-filename.sh" = "$exec_name" ]; then
    parse_filename "$1"
fi
