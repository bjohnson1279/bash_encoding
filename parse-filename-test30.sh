#!/usr/bin/env bash
source encode-all.sh &>/dev/null || true # Source it to get getDuration function

echo "Benchmarking ffprobe inside getDuration..."
time for i in {1..100}; do
    getDuration "dummy.ts" > /dev/null
done
