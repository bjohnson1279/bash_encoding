#!/bin/bash
echo "Double ffprobe:"
time for i in {1..100}; do
    ffprobe -v error -i "dummy.ts" >/dev/null 2>&1
    ffprobe -v error -select_streams v:0 -show_entries format=duration:stream=duration -of flat -i "dummy.ts" 2>/dev/null >/dev/null
done
echo "Single ffprobe:"
time for i in {1..100}; do
    ffprobe -v error -select_streams v:0 -show_entries format=duration:stream=duration -of flat -i "dummy.ts" 2>/dev/null >/dev/null
done
