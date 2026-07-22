#!/usr/bin/env bash
FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"

echo "Benchmarking array replacements in encode-all.sh vs single loop:"
time for j in {1..20000}; do
    new_file="Test Show 0E12"
    new_file="${new_file//0E/0 E}"
    new_file="${new_file//1E/1 E}"
    new_file="${new_file//2E/2 E}"
    new_file="${new_file//3E/3 E}"
    new_file="${new_file//4E/4 E}"
    new_file="${new_file//5E/5 E}"
    new_file="${new_file//6E/6 E}"
    new_file="${new_file//7E/7 E}"
    new_file="${new_file//8E/8 E}"
    new_file="${new_file//9E/9 E}"
done

echo "Benchmarking native bash regex replacement:"
time for j in {1..20000}; do
    new_file="Test Show 0E12"
    if [[ "$new_file" =~ ^(.*[0-9])E(.*)$ ]]; then
        new_file="${BASH_REMATCH[1]} E${BASH_REMATCH[2]}"
    fi
done
