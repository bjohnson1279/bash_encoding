#!/usr/bin/env bash
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

FILE="Test Show S01E02 (2020).ts"
SHOW_NAME="InitialValue"
parseFilename "$FILE" episode_data

echo "Original SHOW_NAME: $SHOW_NAME"

if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
    EXTRACTED_SHOW_NAME="${BASH_REMATCH[1]}"
    EXTRACTED_SHOW_NAME="${EXTRACTED_SHOW_NAME//\\\"/\"}"
else
    EXTRACTED_SHOW_NAME=""
fi

echo "Extracted SHOW_NAME: $EXTRACTED_SHOW_NAME"

if [[ "$SHOW_NAME" == "$EXTRACTED_SHOW_NAME" ]]; then
    echo "They are identical!"
else
    echo "They are different!"
fi
