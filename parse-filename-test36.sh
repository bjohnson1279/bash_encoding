#!/usr/bin/env bash
source encode-all.sh &>/dev/null || true # Source it to get parseFilename function

echo "Benchmarking regex match via subshell execution vs. eval:"

FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking jq in loop:"
time for j in {1..2000}; do
    parseFilename "$FILE" episode_data > /dev/null
    SHOW_NAME=$(echo "$episode_data" | grep -o '"show":"[^"]*"' | cut -d'"' -f4)
done
