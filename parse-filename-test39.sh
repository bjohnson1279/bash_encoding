#!/usr/bin/env bash
FILE="Another Show - S02E10 - A New Day (2022).ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

echo "Benchmarking with regex extraction:"
time for j in {1..20000}; do
    parseFilename "$FILE" episode_data >/dev/null
    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
        SHOW_NAME_TMP="${BASH_REMATCH[1]}"
        SHOW_NAME_TMP="${SHOW_NAME_TMP//\\\"/\"}"
    else
        SHOW_NAME_TMP=""
    fi
done

echo "Benchmarking relying on global SHOW_NAME:"
time for j in {1..20000}; do
    parseFilename "$FILE" episode_data >/dev/null
done
