#!/usr/bin/env sh

# Encode all files of a specific extension in a directory to .mp4

if [ -z "$1" ]; then
    printf "Usage: %s <extension>\n" "$0" >&2
    exit 1
fi

EXT="$1"
# Remove leading dot if present
EXT="${EXT#.}"

# --- Configuration ---
# FFMPEG encoder to be used
ENC_TYPE="libx264"
# Video filters applied, default is yadif for deinterlacing
VF="yadif"
# Speed of encoding process, default is veryslow for smaller file sizes
PRESET="veryslow"
# Quality level, default is 21
QUALITY=21

# shellcheck disable=SC3045
# Find and loop through all files with the given extension in the current directory
find . -type f -name "*.$EXT" -print0 | while IFS= read -r -d '' i; do
    # Construct the output filename
    new_file="${i%.*}.mp4"

    printf "Encoding '%s' to '%s'...\n" "$i" "$new_file"

    # Construct and execute the ffmpeg command
    ffmpeg -nostdin -i "$i" \
        -vf "$VF" \
        -c:v "$ENC_TYPE" \
        -preset "$PRESET" \
        -crf "$QUALITY" \
        -pix_fmt yuv420p \
        -c:a copy \
        -movflags faststart \
        -y "$new_file"
done

printf "Done.\n"
