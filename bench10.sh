#!/bin/bash

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

cleanup_name_pure_posix_3() {
    local val="$1"

    # Nested loops
    while [ "$val" != "${val#*.}" ] || [ "$val" != "${val#*_}" ]; do
        val="${val%%.*} ${val#*.}"
        val="${val%%_*} ${val#*_}"
    done

    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

iters=10000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "POSIX IFS:"
time for i in $(seq 1 $iters); do
    cleanup_name_posix "$str" > /dev/null
done

echo "Pure POSIX Loop 3:"
time for i in $(seq 1 $iters); do
    cleanup_name_pure_posix_3 "$str" > /dev/null
done
