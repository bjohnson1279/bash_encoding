#!/usr/bin/env sh
cleanup_name_new() {
    # Replace dots and underscores with spaces
    # We use parameter expansion ${1//...} which is a bashism but this script is executed in bash
    local val="${1//[._]/ }"

    # Strip leading whitespace
    val="${val#"${val%%[! ]*}"}"
    # Strip trailing whitespace
    val="${val%"${val##*[! ]}"}"
    # Strip trailing " -" if present
    val="${val%" -"}"
    # Strip trailing whitespace again
    val="${val%"${val##*[! ]}"}"
    printf '%s\n' "$val"
}

cleanup_name_new "  ._ Foo.Bar_Baz ._ - "
