#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_FILE="${SCRIPT_DIR}/tmp_parseFilename.sh"
trap 'rm -f "$TMP_FILE"' EXIT
sed -n '/^parseFilename() {/,/^}/p' "$SCRIPT_DIR/encode-all.sh" > "$TMP_FILE"
source "$TMP_FILE"

start=$SECONDS
for i in {1..1000}; do
    parseFilename "Show Name (2020) S01E01.ts" >/dev/null
done
echo "Duration: $((SECONDS - start)) seconds"
