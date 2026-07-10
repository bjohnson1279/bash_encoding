#!/usr/bin/env sh

# Encode specified video extensions in a directory to .mp4

# --- Configuration ---
# FFMPEG encoder to be used
ENC_TYPE="libx264"
# Video filters applied, default is yadif for deinterlacing
VF="yadif"
# Speed of encoding process, default is veryslow for smaller file sizes
PRESET="veryslow"
# Quality level, default is 21
QUALITY=21

EXTENSIONS="$*"

if [ -z "$EXTENSIONS" ]; then
    EXTENSIONS="mkv m4v mov ts"
fi

for ext in $EXTENSIONS; do
    # Find and loop through all files with the given extension in the current directory
    find . -type f -name "*.$ext" | while IFS= read -r i; do
        # Construct the output filename
        new_file="${i%.*}.mp4"

        echo "Encoding '$i' to '$new_file'..."

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
done

echo "Done."
