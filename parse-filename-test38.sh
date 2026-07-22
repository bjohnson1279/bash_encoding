#!/usr/bin/env bash
FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking regex match vs JSON parse inside loop:"
time for j in {1..20000}; do
    parseFilename "$FILE" episode_data > /dev/null
done
