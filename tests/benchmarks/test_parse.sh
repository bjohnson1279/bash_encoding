#!/bin/bash

# Old slow method using subshells and sed
cleanup_name_sed() {
    echo "$1" | sed 's/[._]/ /g; s/^ *//; s/ *$//'
}

# POSIX method using IFS
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

# Optimized bash parameter expansion method
cleanup_name_bash() {
    local val="${1//[._]/ }"

    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

iters=10000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "Benchmarking cleanup_name functions with $iters iterations..."
echo ""

echo "1. SED (subshell + sed process):"
{ time for i in $(seq 1 $iters); do cleanup_name_sed "$str" > /dev/null; done; } 2>&1
echo ""

echo "2. POSIX (IFS + parameter expansion):"
{ time for i in $(seq 1 $iters); do cleanup_name_posix "$str" > /dev/null; done; } 2>&1
echo ""

echo "3. BASH (Native parameter expansion):"
{ time for i in $(seq 1 $iters); do cleanup_name_bash "$str" > /dev/null; done; } 2>&1
echo ""
