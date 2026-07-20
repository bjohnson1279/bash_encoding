#!/usr/bin/env bash
source encode-all.sh &>/dev/null || true # Source it to get getDuration function

echo "Benchmarking removing JSON formatting in parseFilename..."

FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking with JSON formatting:"
time for j in {1..20000}; do
    parseFilename "$FILE" episode_data > /dev/null
done
