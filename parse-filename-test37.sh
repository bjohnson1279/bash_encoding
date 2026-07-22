#!/usr/bin/env bash
FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"

echo "Benchmarking file extension stripping:"
time for j in {1..20000}; do
    FILE_BASE="${FILE%.ts}"
done
