#!/usr/bin/env bash
echo "Benchmarking shopt:"
time for j in {1..10000}; do
    shopt -s extglob
    shopt -u extglob
done
