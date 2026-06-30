#!/usr/bin/env sh

# Encode all .m4v files in a directory to .mp4

# --- Configuration ---
# FFMPEG encoder to be used
ENC_TYPE="libx264"
# Video filters applied, default is yadif for deinterlacing
VF="yadif"
# Speed of encoding process, default is veryslow for smaller file sizes
PRESET="veryslow"
# Quality level, default is 21
QUALITY=21

# Find and loop through all .m4v files in the current directory
find . -type f -name "*.m4v" | while read -r i; do
    # Construct the output filename
    new_file="${i%.*}.mp4"

    echo "Encoding '$i' to '$new_file'..."

    # Construct and execute the ffmpeg command
    ffmpeg -i "$i" \
        -vf "$VF" \
        -c:v "$ENC_TYPE" \
        -preset "$PRESET" \
        -crf "$QUALITY" \
        -pix_fmt yuv420p \
        -c:a copy \
        -movflags faststart \
        -y "$new_file"
done

echo "Done."
