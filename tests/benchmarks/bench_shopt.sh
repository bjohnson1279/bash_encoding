#!/bin/bash
iters=10000

echo "Inside loop:"
time for i in $(seq 1 $iters); do
    shopt -u globstar nullglob
done

echo "Outside loop:"
time {
    for i in $(seq 1 $iters); do
        :
    done
    shopt -u globstar nullglob
}
