#!/bin/bash
time for j in {1..20000}; do
    # Inside encode-all.sh
    SHOW_NAME="Initial"
    episode_data='{"show":"Test Show","season":"01","episode":"02"}'

    if [[ "$episode_data" =~ \"show\":\"(([^\"\\]|\\.)*)\" ]]; then
        SHOW_NAME="${BASH_REMATCH[1]}"
        SHOW_NAME="${SHOW_NAME//\\\"/\"}"
    else
        SHOW_NAME=""
    fi
done

time for j in {1..20000}; do
    SHOW_NAME="Initial"
    episode_data='{"show":"Test Show","season":"01","episode":"02"}'
    # doing nothing is what relying on global SHOW_NAME does, but we still need to strip escapes if it's there
    # Wait, parseFilename creates esc_show using parameter expansion, but the global SHOW_NAME variable is
    # NOT escaped during the process. Wait! The global SHOW_NAME in parseFilename is set on line 57-61:
    # SHOW_NAME="$FILE \([0-9]*}"
    # SHOW_NAME="${SHOW_NAME% S[0-9]*}"
    # SHOW_NAME="${SHOW_NAME##*( )}"
    # SHOW_NAME="${SHOW_NAME%%*( )}"
done
