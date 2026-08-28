#!/usr/bin/env bash

FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"

source <(sed -n '/^cleanup_name() {/,/^}/p; /^json_escape() {/,/^}/p; /^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking with regex..."
time for i in {1..5000}; do
    parseFilename "$FILE" episode_data > /dev/null
    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
        SHOW_NAME_1="${BASH_REMATCH[1]}"
        SHOW_NAME_1="${SHOW_NAME_1//\\\"/\"}"
    else
        SHOW_NAME_1=""
    fi
done

echo "Benchmarking without regex..."
time for i in {1..5000}; do
    parseFilename "$FILE" episode_data > /dev/null
    SHOW_NAME_2="$SHOW_NAME"
done
