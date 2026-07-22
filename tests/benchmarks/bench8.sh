#!/bin/bash
shopt -s extglob

cleanup_name_extglob_space() {
    local val="${1//[._]/ }"
    val="${val##+([[:space:]])}"
    val="${val%%+([[:space:]])}"
    val="${val%" -"}"
    val="${val%%+([[:space:]])}"
    printf '%s\n' "$val"
}

cleanup_name_extglob_simple() {
    local val="${1//[._]/ }"
    val="${val##+( )}"
    val="${val%%+( )}"
    val="${val%" -"}"
    val="${val%%+( )}"
    printf '%s\n' "$val"
}

cleanup_name_bash_pattern() {
    local val="${1//[._]/ }"
    val="${val#"${val%%[! ]*}"}"
    val="${val%"${val##*[! ]}"}"
    val="${val%" -"}"
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

iters=10000
str=" ._ Show.Name._.S01E02._.Episode.Title._ "

echo "extglob [[:space:]]:"
time for i in $(seq 1 $iters); do
    cleanup_name_extglob_space "$str" > /dev/null
done

echo "extglob ( ):"
time for i in $(seq 1 $iters); do
    cleanup_name_extglob_simple "$str" > /dev/null
done

echo "bash_pattern:"
time for i in $(seq 1 $iters); do
    cleanup_name_bash_pattern "$str" > /dev/null
done
