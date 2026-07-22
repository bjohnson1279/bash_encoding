#!/usr/bin/env bash
source ./parse-filename.sh

echo "Benchmarking parse_filename..."
time for i in {1..1000}; do
    parse_filename "Show.Name.S01E02.Episode.Title.mkv" > /dev/null
done
echo "Benchmarking cleanup_name..."
time for i in {1..1000}; do
    cleanup_name "Show.Name.S01E02.Episode.Title.mkv" > /dev/null
done
echo "Benchmarking json_escape..."
time for i in {1..1000}; do
    json_escape "Show.Name.S01E02.Episode.Title.mkv" > /dev/null
done
