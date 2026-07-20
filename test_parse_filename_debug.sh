#!/bin/bash
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

for i in "Another Show - S02E10 - A New Day (2022).ts" "Test Show S01E02 (2020).ts"; do
    parseFilename "$i" episode_data
    echo "FILE: $i"
    echo "JSON show: $(echo "$episode_data" | grep -o '"show":"[^"]*"' | cut -d'"' -f4)"
    echo "GLOBAL SHOW_NAME: $SHOW_NAME"
    echo "---"
done
