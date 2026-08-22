#!/bin/bash
base_name="Show Name (2020) - S01E02 - Title (2020-01-01 12:00:00)"

if [[ "$base_name" =~ ^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]+(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$ ]]; then
    echo "Matched Regex 1"
    echo "Title: ${BASH_REMATCH[5]}"
else
    echo "Did not match Regex 1"
fi
