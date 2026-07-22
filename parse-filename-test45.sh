#!/usr/bin/env bash
echo "Benchmarking removing JSON string construction"
time for j in {1..20000}; do
    esc_show="Show"
    esc_season="01"
    esc_episode="02"
    esc_title="Title"
    esc_premiered="2020"
    esc_date="20200101"
    local json_str
    printf -v json_str '{"show":"%s","season":"%s","episode":"%s","title":"%s","premiered":"%s","date":"%s"}' \
        "$esc_show" \
        "$esc_season" \
        "$esc_episode" \
        "$esc_title" \
        "$esc_premiered" \
        "$esc_date"
done

echo "Benchmarking skipping it:"
time for j in {1..20000}; do
    :
done
