#!/usr/bin/env bash

# Benchmarking find vs extglob expansion
mkdir -p dummy_dir
for i in {1..1000}; do
    touch "dummy_dir/file_$i.ts"
done

echo "Benchmarking find:"
time for j in {1..5}; do
    count=0
    find dummy_dir -type f -name "*.ts" -print0 | while IFS= read -r -d '' i; do
        count=$((count+1))
    done
done

echo "Benchmarking extglob array:"
time for j in {1..5}; do
    count=0
    shopt -s nullglob
    ts_files=(dummy_dir/*.ts)
    for i in "${ts_files[@]}"; do
        count=$((count+1))
    done
    shopt -u nullglob
done

rm -rf dummy_dir
