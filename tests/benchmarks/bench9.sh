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

cleanup_name_sed() {
    echo "$1" | sed 's/[._]/ /g; s/^ *//; s/ *$//'
}

cleanup_name_pure_posix() {
    local val="$1"

    while [ "$val" != "${val#*.}" ] || [ "$val" != "${val#*_}" ]; do
        case "$val" in
            *.*) val="${val%%.*} ${val#*.}" ;;
            *_*) val="${val%%_*} ${val#*_}" ;;
        esac
    done

    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

cleanup_name_pure_posix_2() {
    local val="$1"

    # In POSIX sh, replacing all occurrences of a character requires a loop
    while true; do
        case "$val" in
            *.*) val="${val%%.*} ${val#*.}" ;;
            *) break ;;
        esac
    done
    while true; do
        case "$val" in
            *_*) val="${val%%_*} ${val#*_}" ;;
            *) break ;;
        esac
    done

    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

cleanup_name_bash_substitution() {
    local val="${1//[._]/ }"
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

echo "Bash Substitution:"
time for i in $(seq 1 $iters); do
    cleanup_name_bash_substitution "$str" > /dev/null
done

echo "Pure POSIX Loop:"
time for i in $(seq 1 $iters); do
    cleanup_name_pure_posix "$str" > /dev/null
done

echo "Pure POSIX Loop 2:"
time for i in $(seq 1 $iters); do
    cleanup_name_pure_posix_2 "$str" > /dev/null
done
