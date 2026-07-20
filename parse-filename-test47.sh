#!/usr/bin/env bash
source encode-all.sh &>/dev/null || true

echo "Benchmarking regex match vs JSON parse inside loop:"
time for j in {1..20000}; do
    # Do something minimal
    :
done

echo "Benchmarking removing regex match AND formatting JSON:"
time for j in {1..20000}; do
    :
done
