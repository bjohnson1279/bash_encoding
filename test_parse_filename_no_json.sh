#!/bin/bash
FILE="The Big Bang Theory - S05E12 - The Shiny Trinket Maneuver.ts"
source <(sed -n '/^parseFilename() {/,/^}/p' encode-all.sh)

time for i in {1..20000}; do
    parseFilename "$FILE" episode_data > /dev/null
done

# Modified version to skip JSON
parseFilename_nojson() {
    FILE="${1%.ts}"

    shopt -s extglob
    SHOW_NAME="$FILE \([0-9]*}"
    SHOW_NAME="${SHOW_NAME% S[0-9]*}"
    SHOW_NAME="${SHOW_NAME##*( )}"
    SHOW_NAME="${SHOW_NAME%%*( )}"
    shopt -u extglob

    YEAR_PREMIERED=${FILE//${SHOW_NAME} /}
    YEAR_PREMIERED=${YEAR_PREMIERED%\) *}
    YEAR_PREMIERED=${YEAR_PREMIERED//[^0-9]}
    YEAR_PREMIERED=${YEAR_PREMIERED:0:4}

    DATE_TIME=""
    DATE_TIME=${FILE//${SHOW_NAME} /}
    DATE_TIME=${DATE_TIME//\${YEAR_PREMIERED\) /}
    DATE_TIME=${DATE_TIME//- /}
    DATE_TIME=${DATE_TIME%% [A-Z]*}
    DATE_TIME=${DATE_TIME#^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9] [0-9][0-9] [0-9][0-9] [0-9][0-9]}
    shopt -s extglob
    DATE_TIME=${DATE_TIME##*( )}
    DATE_TIME=${DATE_TIME%%*( )}
    shopt -u extglob

    DATE=""
    DATE=${DATE_TIME// [0-9][0-9] [0-9][0-9] [0-9][0-9]/}
    shopt -s extglob
    DATE=${DATE##*( )}
    DATE=${DATE%%*( )}
    shopt -u extglob

    NUM_DATE=${DATE//-/}
    YEAR=${DATE:0:4}

    TIME=""
    TIME=${DATE_TIME//$DATE/}
    shopt -s extglob
    TIME=${TIME##*( )}
    TIME=${TIME%%*( )}

    FILE=${FILE//${TIME}/}
    FILE=${FILE//${YEAR_PREMIERED}\)/}
    FILE=${FILE//\(stop*/}
    FILE=${FILE//\(start*/}

    SEASON=${FILE//${SHOW_NAME} \(/}
    SEASON=${FILE//${SHOW_NAME}/}
    SEASON=${SEASON%E*}
    SEASON=${SEASON//[^0-9]}
    SEASON=${SEASON:0:4}

    EPISODE=${FILE//${SHOW_NAME}/}
    EPISODE=${EPISODE//\(${YEAR_PREMIERED}\)/}
    if [ "$SEASON" == "$YEAR" ]; then
        EPISODE=${NUM_DATE//${SEASON}/}
    else
        EPISODE=${EPISODE//${TIME}/}
        EPISODE=${EPISODE// S${SEASON}E/}
        EPISODE=${EPISODE//[^0-9]}
    fi

    EPISODE_TITLE=${FILE//${SHOW_NAME} /}
    EPISODE_TITLE=${EPISODE_TITLE//\(${YEAR_PREMIERED}\)/}
    EPISODE_TITLE=${EPISODE_TITLE// \- /}
    EPISODE_TITLE=${EPISODE_TITLE//${TIME}/}
    EPISODE_TITLE=${EPISODE_TITLE//S${SEASON}E${EPISODE}/}
    EPISODE_TITLE=${EPISODE_TITLE%%${SHOW_NAME}}}
    EPISODE_TITLE=${EPISODE_TITLE//\(stop*/}
    EPISODE_TITLE=${EPISODE_TITLE//\(start*/}
    EPISODE_TITLE=${EPISODE_TITLE//\([0-9]*/}
    shopt -s extglob
    EPISODE_TITLE=${EPISODE_TITLE##*( )}
    EPISODE_TITLE=${EPISODE_TITLE%%*( )}
    shopt -u extglob

    if [[ "$2" != "--no-json" ]]; then
        local esc_show="${SHOW_NAME//\\/\\\\}"
        esc_show="${esc_show//\"/\\\"}"
        esc_show="${esc_show//$'\n'/\\n}"
        local esc_season="${SEASON//\\/\\\\}"
        esc_season="${esc_season//\"/\\\"}"
        esc_season="${esc_season//$'\n'/\\n}"
        local esc_episode="${EPISODE//\\/\\\\}"
        esc_episode="${esc_episode//\"/\\\"}"
        esc_episode="${esc_episode//$'\n'/\\n}"
        local esc_title="${EPISODE_TITLE//\\/\\\\}"
        esc_title="${esc_title//\"/\\\"}"
        esc_title="${esc_title//$'\n'/\\n}"
        local esc_premiered="${YEAR_PREMIERED//\\/\\\\}"
        esc_premiered="${esc_premiered//\"/\\\"}"
        esc_premiered="${esc_premiered//$'\n'/\\n}"
        local esc_date="${DATE//\\/\\\\}"
        esc_date="${esc_date//\"/\\\"}"
        esc_date="${esc_date//$'\n'/\\n}"
        local json_str
        printf -v json_str '{"show":"%s","season":"%s","episode":"%s","title":"%s","premiered":"%s","date":"%s"}' \
            "$esc_show" "$esc_season" "$esc_episode" "$esc_title" "$esc_premiered" "$esc_date"
        if [[ -n "$2" ]]; then
            local -n out_var="$2"
            out_var="$json_str"
        else
            printf '%s\n' "$json_str"
        fi
    fi
}

echo "Benchmarking NO JSON formatting:"
time for i in {1..20000}; do
    parseFilename_nojson "$FILE" --no-json > /dev/null
done
