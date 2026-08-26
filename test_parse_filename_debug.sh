#!/bin/bash
source <(sed -n '/^cleanup_name() {/,/^}/p; /^json_escape() {/,/^}/p; /^parseFilename() {/,/^}/p' encode-all.sh)

for i in "Another Show - S02E10 - A New Day (2022).ts" "Test Show S01E02 (2020).ts"; do
    parseFilename "$i" episode_data
    printf '%s\n' "FILE: $i"
    printf '%s\n' "JSON show: $(printf '%s\n' "$episode_data" | grep -o '"show":"[^"]*"' | cut -d'"' -f4)"
    printf '%s\n' "GLOBAL SHOW_NAME: $SHOW_NAME"
    printf '%s\n' "---"
done
