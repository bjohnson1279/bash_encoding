#!/bin/bash
cleanup_name_sed() {
    echo "$1" | sed 's/[._]/ /g; s/^ *//; s/ *$//'
}

cleanup_name_bash() {
    local val="${1//[._]/ }"
    shopt -s extglob
    val="${val##+([[:space:]])}"
    val="${val%%+([[:space:]])}"
    printf '%s\n' "$val"
}

iters=1000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "SED:"
time for i in $(seq 1 $iters); do
    res=$(cleanup_name_sed "$str")
done

echo "BASH (extglob):"
time for i in $(seq 1 $iters); do
    res=$(cleanup_name_bash "$str")
done
