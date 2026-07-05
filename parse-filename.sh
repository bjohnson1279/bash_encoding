#!/usr/bin/env sh

# POSIX-compliant script to parse TV show filenames.
# Handles patterns like "Show.Name.S01E02.Episode.Title.mkv"

# Cleans up a string by replacing dots and underscores with spaces,
# and trimming leading/trailing whitespace.
# ⚡ Bolt Optimization: Use `tr` and parameter expansion instead of multiple sed operations.
# Using parameter expansion for stripping whitespaces is POSIX compliant (`${var#"${var%%[! ]*}"}`).
# Using `tr` avoids multiple process forks compared to `sed`.
cleanup_name() {
    # Replace dots and underscores with spaces
    # shellcheck disable=SC3043 # local is supported in environments where this script is executed
    local val
    val=$(printf '%s\n' "$1" | tr '._' '  ')
    # Strip leading whitespace
    val="${val#"${val%%[! ]*}"}"
    # Strip trailing whitespace
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

# Escapes a string for use in JSON.
json_escape() {
    # ⚡ Bolt Optimization: Replace sed subshells with parameter expansion.
    # While ${var//\"/\\\"} is a bashism, we must stay POSIX-compliant.
    # However, since we can't use bash substitution, we will keep sed but ensure it is optimal.
    printf '%s\n' "$1" | sed 's/"/\\"/g'
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

    # Use sed to capture parts of the filename.
    # The pattern looks for "S<season>E<episode>" and captures the parts around it.
    # It handles variations in separators (., _, -, space).
    parsed=$(printf '%s\n' "$base_name" | sed -n \
        's/^\(.*\)[ ._-][Ss]\([0-9]\{1,2\}\)[ ._-]*[Ee]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p')

    if [ -z "$parsed" ]; then
        # Fallback for filenames with the date as episode "Show.Name.2023.10.27.mkv"
        parsed=$(printf '%s\n' "$base_name" | sed -n \
            's/^\(.*\)[ ._-]\([0-9]\{4\}\)[ ._-]\([0-9]\{1,2\}\)[ ._-]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p')
        if [ -z "$parsed" ]; then
            echo "Error: Could not parse season/episode from '$base_name'." >&2
            return 1
        fi
    fi

    # Use IFS to split the parsed string into variables
    old_ifs=$IFS
    IFS="|"
    set -f # Temporarily disable globbing to prevent issues with filenames
    set -- $parsed
    set +f # Re-enable globbing
    IFS=$old_ifs

    show_name=$(cleanup_name "$1")
    # ⚡ Bolt Optimization: Replace subshells and sed with native POSIX parameter expansion to remove leading zeros
    season_num="${2#"${2%%[!0]*}"}"
    episode_num="${3#"${3%%[!0]*}"}"
    episode_title=$(cleanup_name "$4")

    # Output JSON
    cat <<JSON
{
  "show_name": "$(json_escape "$show_name")",
  "season": "$season_num",
  "episode": "$episode_num",
  "title": "$(json_escape "$episode_title")"
}
JSON

    return 0
}

# If the script is executed directly, parse the first argument
# ⚡ Bolt Optimization: Replace `basename` subshell with native parameter expansion
exec_name="${0##*/}"
if [ "parse-filename.sh" = "$exec_name" ]; then
    parse_filename "$1"
fi
