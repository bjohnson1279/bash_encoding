#!/usr/bin/env bash
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

for FILE in "Another Show - S02E10 - A New Day (2022).ts" "Test Show S01E02 (2020).ts" "Something \"Quotes\" S01E01.ts"; do
    SHOW_NAME=""
    parseFilename "$FILE" episode_data > /dev/null

    echo "FILE: $FILE"
    echo "Global SHOW_NAME: $SHOW_NAME"

    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
        EXTRACTED="${BASH_REMATCH[1]}"
        EXTRACTED="${EXTRACTED//\\\"/\"}"
        EXTRACTED="${EXTRACTED//\\\\/\\}"
        EXTRACTED="${EXTRACTED//\\n/$'\n'}"
    else
        EXTRACTED=""
    fi
    echo "Extracted: $EXTRACTED"
    echo "---"
done
