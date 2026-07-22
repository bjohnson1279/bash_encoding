#!/usr/bin/env bash

# Test parsing loop speed inside encode-all.sh vs native bash loop

FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"

# parseFilename function from encode-all.sh
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking regex match..."
time for i in {1..20000}; do
    episode_data='{"show":"Another Show -","season":"02","episode":"10","title":"A New Day","premiered":"2022","date":"2022"}'
    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
        SHOW_NAME="${BASH_REMATCH[1]}"
        SHOW_NAME="${SHOW_NAME//\\\"/\"}"
    else
        SHOW_NAME=""
    fi
done

echo "Benchmarking variable reading..."
time for i in {1..20000}; do
    episode_data='{"show":"Another Show -","season":"02","episode":"10","title":"A New Day","premiered":"2022","date":"2022"}'
    SHOW_NAME_TEMP="$SHOW_NAME"
done
