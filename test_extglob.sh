#!/bin/bash
cleanup_name() {
    local val="${1//[._]/ }"

    local extglob_set=0
    if shopt -q extglob 2>/dev/null; then
        extglob_set=1
    else
        shopt -s extglob
    fi

    val="${val##+([[:space:]])}"
    val="${val%%+([[:space:]])}"

    if [ "$extglob_set" -eq 0 ]; then
        shopt -u extglob
    fi

    printf '%s\n' "$val"
}

cleanup_name "  ._ Foo.Bar_Baz ._  "
