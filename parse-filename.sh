#!/usr/bin/env sh

# POSIX-compliant script to parse TV show filenames.
# Handles patterns like "Show.Name.S01E02.Episode.Title.mkv"

# Cleans up a string by replacing dots and underscores with spaces,
# and trimming leading/trailing whitespace.
cleanup_name() {
    echo "$1" | sed 's/[._]/ /g; s/^ *//; s/ *$//'
}

# Escapes a string for use in JSON.
json_escape() {
    echo "$1" | sed 's/"/\\"/g'
}

parse_filename() {
    if [ -z "$1" ]; then
        echo "Usage: parse_filename \"<filename>\""
        return 1
    fi

    # Remove directory path and file extension
    base_name=$(basename "$1")
    base_name="${base_name%.*}"

    # Use sed to capture parts of the filename.
    # The pattern looks for "S<season>E<episode>" and captures the parts around it.
    # It handles variations in separators (., _, -, space).
    parsed=$(echo "$base_name" | sed -n \
        's/^\(.*\)[ ._-][Ss]\([0-9]\{1,2\}\)[ ._-]*[Ee]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p')

    if [ -z "$parsed" ]; then
        # Fallback for filenames with the date as episode "Show.Name.2023.10.27.mkv"
        parsed=$(echo "$base_name" | sed -n \
            's/^\(.*\)[ ._-]\([0-9]\{4\}\)[ ._-]\([0-9]\{1,2\}\)[ ._-]\([0-9]\{1,2\}\)\(.*\)$/\1|\2|\3|\4/p')
        if [ -z "$parsed" ]; then
            echo "Error: Could not parse season/episode from '$base_name'." >&2
            return 1
        fi
    fi

    # Use IFS to split the parsed string into variables
    old_ifs=$IFS
    IFS="|"
    set -- $parsed
    IFS=$old_ifs

    show_name=$(cleanup_name "$1")
    season_num=$(echo "$2" | sed 's/^0*//') # Remove leading zeros
    episode_num=$(echo "$3" | sed 's/^0*//') # Remove leading zeros
    episode_title=$(cleanup_name "$4")

    # Output JSON
    cat <<EOF
{
  "show_name": "$(json_escape "$show_name")",
  "season": "$season_num",
  "episode": "$episode_num",
  "title": "$(json_escape "$episode_title")"
}
EOF

    return 0
}

# If the script is executed directly, parse the first argument
if [ "parse-filename.sh" = "$(basename "$0")" ]; then
    parse_filename "$1"
fi
