#!/usr/bin/env bash

echo "Benchmarking printf -v:"
time for j in {1..10000}; do
    show_name="Show"
    season="01"
    episode="02"
    title="Title"
    printf -v new_filename "%s - S%02dE%02d - %s.mp4" "$show_name" "$season" "$episode" "$title"
done

echo "Benchmarking variable concatenation:"
time for j in {1..10000}; do
    show_name="Show"
    season="01"
    episode="02"
    title="Title"
    new_filename="${show_name} - S${season}E${episode} - ${title}.mp4"
done
