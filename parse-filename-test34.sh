#!/usr/bin/env bash

# Test parsing loop speed inside encode-all.sh vs native bash loop

echo "Benchmarking tr vs parameter expansion for invalid chars:"
time for j in {1..10000}; do
    new_filename="Test/Show\\Name?Title%*<>|:.mp4"
    new_filename="${new_filename//[\/\\\\?%*:|\"<>]/_}"
done

echo "Benchmarking tr:"
time for j in {1..10000}; do
    new_filename="Test/Show\\Name?Title%*<>|:.mp4"
    new_filename=$(echo "$new_filename" | tr '/\\?%*:|"<>' '_')
done
