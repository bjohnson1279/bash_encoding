#!/bin/bash

# Current implementation
cleanup_name_posix() {
    local val
    local IFS="._"
    local old_set="$-"

    set -f
    set -- $1

    IFS=" "
    val="$*"

    case "$old_set" in
        *f*) ;;
        *) set +f ;;
    esac

    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

shopt -s extglob
cleanup_name_bash() {
    # shellcheck disable=SC3043,SC3060,SC3054
    local val="${1//[._]/ }"

    val="${val##+([[:space:]])}"
    val="${val%%+([[:space:]])}"
    val="${val%" -"}"
    val="${val%%+([[:space:]])}"

    printf '%s\n' "$val"
}

iters=10000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "POSIX (current):"
time for i in $(seq 1 $iters); do
    cleanup_name_posix "$str" > /dev/null
done

echo "BASH (extglob):"
time for i in $(seq 1 $iters); do
    cleanup_name_bash "$str" > /dev/null
done
