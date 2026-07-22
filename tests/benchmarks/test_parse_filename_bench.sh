#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parse-filename.sh"

start=$SECONDS
for i in {1..1000}; do
    parse_filename "Show.Name.S01E02.Episode.Title.mkv" >/dev/null
done
echo "Duration: $((SECONDS - start)) seconds"
