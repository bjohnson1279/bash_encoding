#!/usr/bin/env bash
FILE="Another Show - S02E10 - A New Day (2022).ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

time for i in {1..20000}; do
    parseFilename "$FILE" --no-json >/dev/null
done
