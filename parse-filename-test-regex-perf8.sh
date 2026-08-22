#!/bin/bash

# Original Regex 1 from the script
R1='^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]+(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$'
# Original Regex 3 from the script
R3='^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]*(.*)$'

# The issue in PR review was that R3 WITHOUT R1 fails to strip dates from files that have BOTH a date AND a time,
# because R3's date-stripping logic uses: `^(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$`.
# Let's test that theory.

base_name="Show Name (2020) S01E02 Title (2020-01-01 12:00:00)"

echo "Testing R1:"
if [[ "$base_name" =~ $R1 ]]; then
    echo "Matched R1"
    echo "Title: ${BASH_REMATCH[5]}"
else
    echo "Did not match R1"
fi

echo "Testing R3 with strip logic:"
if [[ "$base_name" =~ $R3 ]]; then
    echo "Matched R3"
    title_raw="${BASH_REMATCH[5]}"
    if [[ "$title_raw" =~ ^(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$ ]]; then
        echo "Stripped date"
        title_raw="${BASH_REMATCH[1]}"
    fi
    echo "Title: $title_raw"
else
    echo "Did not match R3"
fi
