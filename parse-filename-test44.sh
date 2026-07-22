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

echo "Benchmarking removing regex match AND formatting JSON:"
time for j in {1..20000}; do
    # When passed `--no-json`, it skips formatting JSON altogether
    # We must patch parseFilename to support `--no-json`.
    parseFilename "$FILE" > /dev/null
    # Since SHOW_NAME is populated globally, we don't need JSON to get SHOW_NAME!
done
