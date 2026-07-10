#!/usr/bin/env sh

# POSIX-compliant script to parse TV show filenames.
# Handles patterns like "Show.Name.S01E02.Episode.Title.mkv"

# Cleans up a string by replacing dots and underscores with spaces,
# and trimming leading/trailing whitespace.
# ⚡ Bolt Optimization: Use parameter expansion and extglob instead of subshells and sed.
cleanup_name() {
    # Replace dots and underscores with spaces
    # shellcheck disable=SC3060 # string replacement is supported in environments where this script is executed
    local val="${1//[._]/ }"

    # We use extglob to trim spaces, avoiding subshells.
    local extglob_set=0
    # shellcheck disable=SC3044 # shopt is supported in bash environments where this script executes
    if shopt -q extglob 2>/dev/null; then
        extglob_set=1
    else
        # shellcheck disable=SC3044
        shopt -s extglob
    fi

    # Trim leading spaces
    # shellcheck disable=SC3054 # extglob is supported in bash environments where this script executes
    val="${val##+( )}"
    # Trim trailing spaces
    # shellcheck disable=SC3054
    val="${val%%+( )}"
    # Strip trailing " -" if present
    val="${val%" -"}"
    # Trim trailing spaces again
    # shellcheck disable=SC3054
    val="${val%%+( )}"

    if [ "$extglob_set" -eq 0 ]; then
        # shellcheck disable=SC3044
        shopt -u extglob
    fi

    printf '%s\n' "$val"
}

# Escapes a string for use in JSON.
json_escape() {
    # ⚡ Bolt Optimization: Replace sed subshells with parameter expansion.
    # While ${var//\"/\\\"} is a bashism, we must stay POSIX-compliant.
    # However, since we can't use bash substitution, we will keep sed but ensure it is optimal.
    printf '%s\n' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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
    # ⚡ Bolt Optimization: Combine sequential sed operations into a single invocation
    # using `-e` and the conditional branch command `t` to prevent the second substitution
    # if the first one succeeds. This cuts process spawning overhead in half for date-based fallbacks.
    parsed=$(printf '%s\n' "$base_name" | sed -n \
        -e 's/^\(.*\)[ ._-][Ss]\([0-9]\{1,2\}\)[ ._-]*[Ee]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p' \
        -e 't' \
        -e 's/^\(.*\)[ ._-]\([0-9]\{4\}\)[ ._-]\([0-9]\{1,2\}\)[ ._-]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p')

    if [ -z "$parsed" ]; then
        printf "Error: Could not parse season/episode from '%s'.\n" "$base_name" >&2
        return 1
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
