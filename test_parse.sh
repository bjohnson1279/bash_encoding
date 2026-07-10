#!/bin/bash

# Original function from parse-filename.sh
cleanup_name() {
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

# The proposed fix replacing subshells and sed. Wait, the issue says:
# File: parse-filename.sh:9
# Issue: Subshell and sed overhead in cleanup_name function
# Let's check what is AT line 9 exactly.
