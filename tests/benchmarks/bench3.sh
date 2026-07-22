#!/bin/bash
# Old version
cleanup_name_old() {
    echo "$1" | sed 's/[._]/ /g; s/^ *//; s/ *$//'
}

cleanup_name_new() {
    # Replace dots and underscores with spaces
    local val="${1//[._]/ }"

    # Store old shopt state and enable extglob
    local old_shopt
    old_shopt=$(shopt -p extglob)
    shopt -s extglob

    # Trim leading spaces
    val="${val##+([[:space:]])}"
    # Trim trailing spaces
    val="${val%%+([[:space:]])}"

    # Restore shopt state
    eval "$old_shopt"

    printf '%s\n' "$val"
}

iters=1000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "SED:"
time for i in $(seq 1 $iters); do
    res=$(cleanup_name_old "$str")
done

echo "BASH (extglob):"
time for i in $(seq 1 $iters); do
    res=$(cleanup_name_new "$str")
done
