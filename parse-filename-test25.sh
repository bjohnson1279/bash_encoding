#!/usr/bin/env bash

# Test parsing loop speed inside encode-all.sh vs native bash loop

FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"

# parseFilename function from encode-all.sh
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking parseFilename from encode-all.sh..."
time for i in {1..1000}; do
    parseFilename "$FILE" episode_data > /dev/null
done
