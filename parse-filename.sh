#!/bin/bash

parse_filename() {
    local filename="$1"
    local show_name=""
    local season_num=""
    local episode_num=""
    local episode_title="" # We'll try to extract this too, if present

    # Remove file extension for easier parsing
    local base_name=$(basename "$filename")
    base_name="${base_name%.*}"

    echo "Parsing filename: $base_name"

    # Pattern 1: Show.Name.SXXEXX.Episode.Title
    if [[ "$base_name" =~ ^(.*)[.\ -][Ss]([0-9]+)[Ee]([0-9]+)([.\ ](.*))?$ ]]; then
        show_name="${BASH_REMATCH[1]}"
        season_num="${BASH_REMATCH[2]}"
        episode_num="${BASH_REMATCH[3]}"
        episode_title="${BASH_REMATCH[5]}" # This might be empty

        # Clean up show_name: replace dots/underscores with spaces, trim trailing spaces/hyphens
        show_name=$(echo "$show_name" | sed -E 's/(\.|_)/ /g' | sed -E 's/[[:space:]]+$//' | sed -E 's/^[[:space:]]+//')
        show_name=$(echo "$show_name" | sed -E 's/( -)+$//') # Remove trailing " -" if present from parsing "Show Name - S01E01"

        # Clean up episode_title: replace dots/underscores with spaces, trim leading/trailing spaces
        if [[ -n "$episode_title" ]]; then
            episode_title=$(echo "$episode_title" | sed -E 's/(\.|_)/ /g' | sed -E 's/[[:space:]]+$//' | sed -E 's/^[[:space:]]+//')
        fi

    # Pattern 2: Show Name S01 E02 [Episode Title]
    elif [[ "$base_name" =~ ^(.*)[.\ -][Ss]([0-9]+)[[:space:]]*[Ee]([0-9]+)[[:space:]]*[-.]?[[:space:]]*(.*)$ ]]; then
        show_name="${BASH_REMATCH[1]}"
        season_num="${BASH_REMATCH[2]}"
        episode_num="${BASH_REMATCH[3]}"
        episode_title="${BASH_REMATCH[4]}"

        show_name=$(echo "$show_name" | sed -E 's/(\.|_)/ /g' | sed -E 's/[[:space:]]+$//' | sed -E 's/^[[:space:]]+//')
        show_name=$(echo "$show_name" | sed -E 's/( -)+$//')

        if [[ -n "$episode_title" ]]; then
            episode_title=$(echo "$episode_title" | sed -E 's/(\.|_)/ /g' | sed -E 's/[[:space:]]+$//' | sed -E 's/^[[:space:]]+//')
        fi

    # Add more patterns here if needed, or refine the current one
    # For simplicity, we'll focus on the SXXEXX pattern for now, as it's the most common and robust.

    else
        echo "Could not parse season/episode from filename: $base_name"
        return 1 # Indicate failure
    fi

    # Output the parsed information as JSON
    json_output=$(cat <<EOF
{
  "show_name": "$(echo "$show_name" | sed 's/"/\\"/g')",
  "season": "$season_num",
  "episode": "$episode_num",
  "title": "$(echo "$episode_title" | sed 's/"/\\"/g')"
}
EOF
)
    echo "$json_output"

    # Optionally, still export variables if needed elsewhere
    export PARSED_SHOW_NAME="$show_name"
    export PARSED_SEASON_NUM="$season_num"
    export PARSED_EPISODE_NUM="$episode_num"
    export PARSED_EPISODE_TITLE="$episode_title"

    return 0 # Indicate success
}

# --- How to use this function ---
# Example Usage:
# parse_filename "My.Awesome.Show.S01E05.The.Big.Adventure.mkv"
# parse_filename "Another Show - S02E10 - A New Day.mp4"
# parse_filename "Series.Title.S03E01.avi"
# parse_filename "Unparseable Filename.mp4" # This will fail

# Example with a real file (you can comment this out or use your own test files)
# touch "Test.Show.Name.S01E02.Pilot.mkv"
# parse_filename "Test.Show.Name.S01E02.Pilot.mkv"
# rm "Test.Show.Name.S01E02.Pilot.mkv" # Clean up test file

# Remember to source this script or include it in your main script
# For testing:
# parse_filename "The.Mandalorian.S01E01.Chapter.1.mkv"
# parse_filename "Stranger Things - S04E01 - Chapter One - The Hellfire Club.mp4"
# parse_filename "My Show S01E01.avi"
# parse_filename "Game of Thrones S01E01 Winter Is Coming.mp4" # Notice the missing hyphen/dot
# parse_filename "This Is Not A TV Show.mp4" # Should fail

parse_filename "$1"
