#!/bin/bash
source parse-filename.sh > /dev/null 2>&1

time for i in {1..1000}; do
  parse_filename "The.Mandalorian.S01E01.Chapter.1.mkv" > /dev/null
done
