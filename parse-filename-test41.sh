#!/usr/bin/env bash
FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking regex match vs JSON parse inside loop:"
time for j in {1..20000}; do
    parseFilename "$FILE" episode_data > /dev/null
    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
        SHOW_NAME_TMP="${BASH_REMATCH[1]}"
        SHOW_NAME_TMP="${SHOW_NAME_TMP//\\\"/\"}"
    else
        SHOW_NAME_TMP=""
    fi
done

echo "Benchmarking removing regex match:"
time for j in {1..20000}; do
    parseFilename "$FILE" episode_data > /dev/null
    # Since SHOW_NAME is populated globally inside parseFilename, we don't need to do anything!
done
