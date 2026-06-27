#!/bin/bash

parse_filename() {
    local filename="$1"
    local show_name=""
    local season_num=""
    local episode_num=""
    local episode_title="" # We'll try to extract this too, if present

    # Remove file extension for easier parsing
    # Optimization: Use parameter expansion instead of $(basename "$filename")
    local base_name="${filename##*/}"
    base_name="${base_name%.*}"

    echo "Parsing filename: $base_name"

    # Pattern 1: Show.Name.SXXEXX.Episode.Title
    if [[ "$base_name" =~ ^(.*)[.\ -][Ss]([0-9]+)[Ee]([0-9]+)([.\ ](.*))?$ ]]; then
        show_name="${BASH_REMATCH[1]}"
        season_num="${BASH_REMATCH[2]}"
        episode_num="${BASH_REMATCH[3]}"
        episode_title="${BASH_REMATCH[5]}" # This might be empty

        # Clean up show_name: replace dots/underscores with spaces, trim trailing spaces/hyphens
        # Optimization: Avoid sed and subshells by using built-in string replacements
        show_name="${show_name//./ }"
        show_name="${show_name//_/ }"
        # Store original extglob state and enable it safely
        local extglob_was_set=0
        shopt -q extglob && extglob_was_set=1
        shopt -s extglob
        show_name="${show_name##+([[:space:]])}"
        show_name="${show_name%%+([[:space:]])}"
        show_name="${show_name%%+( -)}"

        # Clean up episode_title: replace dots/underscores with spaces, trim leading/trailing spaces
        if [[ -n "$episode_title" ]]; then
            episode_title="${episode_title//./ }"
            episode_title="${episode_title//_/ }"
            episode_title="${episode_title##+([[:space:]])}"
            episode_title="${episode_title%%+([[:space:]])}"
        fi

        # Restore original extglob state
        (( extglob_was_set == 0 )) && shopt -u extglob || true

    # Pattern 2: Show Name S01 E02 [Episode Title]
    elif [[ "$base_name" =~ ^(.*)[.\ -][Ss]([0-9]+)[[:space:]]*[Ee]([0-9]+)[[:space:]]*[-.]?[[:space:]]*(.*)$ ]]; then
        show_name="${BASH_REMATCH[1]}"
        season_num="${BASH_REMATCH[2]}"
        episode_num="${BASH_REMATCH[3]}"
        episode_title="${BASH_REMATCH[4]}"

        # Optimization: Avoid sed and subshells by using built-in string replacements
        show_name="${show_name//./ }"
        show_name="${show_name//_/ }"

        # Store original extglob state and enable it safely
        local extglob_was_set=0
        shopt -q extglob && extglob_was_set=1
        shopt -s extglob

        show_name="${show_name##+([[:space:]])}"
        show_name="${show_name%%+([[:space:]])}"
        show_name="${show_name%%+( -)}"

        if [[ -n "$episode_title" ]]; then
            episode_title="${episode_title//./ }"
            episode_title="${episode_title//_/ }"
            episode_title="${episode_title##+([[:space:]])}"
            episode_title="${episode_title%%+([[:space:]])}"
        fi

        # Restore original extglob state
        (( extglob_was_set == 0 )) && shopt -u extglob || true

    # Add more patterns here if needed, or refine the current one
    # For simplicity, we'll focus on the SXXEXX pattern for now, as it's the most common and robust.

    else
        echo "Could not parse season/episode from filename: $base_name"
        return 1 # Indicate failure
    fi

    # Output the parsed information as JSON
    json_output=$(jq -n \
        --arg show_name "$show_name" \
        --arg season "$season_num" \
        --arg episode "$episode_num" \
        --arg title "$episode_title" \
        '{
          "show_name": $show_name,
          "season": $season,
          "episode": $episode,
          "title": $title
        }')
    echo "$json_output"

    # Optionally, still export variables if needed elsewhere
    export PARSED_SHOW_NAME="$show_name"
    export PARSED_SEASON_NUM="$season_num"
    export PARSED_EPISODE_NUM="$episode_num"
    export PARSED_EPISODE_TITLE="$episode_title"

    return 0 # Indicate success
}

parse_filename "$1"
