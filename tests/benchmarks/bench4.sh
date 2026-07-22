#!/bin/bash

# Old posix implementation from file
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

cleanup_name_bash() {
    # shellcheck disable=SC3043,SC3060,SC3054
    local val="${1//[._]/ }"

    local extglob_set=0
    if shopt -q extglob 2>/dev/null; then
        extglob_set=1
    else
        shopt -s extglob
    fi

    val="${val##+([[:space:]])}"
    val="${val%%+([[:space:]])}"
    val="${val%" -"}"
    val="${val%%+([[:space:]])}"

    if [ "$extglob_set" -eq 0 ]; then
        shopt -u extglob
    fi

    printf '%s\n' "$val"
}

iters=10000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "POSIX:"
time for i in $(seq 1 $iters); do
    cleanup_name_posix "$str" > /dev/null
done

echo "BASH:"
time for i in $(seq 1 $iters); do
    cleanup_name_bash "$str" > /dev/null
done
