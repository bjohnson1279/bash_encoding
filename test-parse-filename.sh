#!/bin/bash

echo "--- Running tests for parse_filename ---"

echo "Test 1:"
./parse-filename.sh "My.Awesome.Show.S01E05.The.Big.Adventure.mkv"
echo ""

echo "Test 2:"
./parse-filename.sh "Another Show - S02E10 - A New Day.mp4"
echo ""

echo "Test 3:"
./parse-filename.sh "Series.Title.S03E01.avi"
echo ""

echo "Test 4 (expected to fail):"
./parse-filename.sh "Unparseable Filename.mp4" || true
echo ""

echo "Test 5 (with real file creation):"
touch "Test.Show.Name.S01E02.Pilot.mkv"
./parse-filename.sh "Test.Show.Name.S01E02.Pilot.mkv"
rm "Test.Show.Name.S01E02.Pilot.mkv"
echo ""

echo "Test 6:"
./parse-filename.sh "The.Mandalorian.S01E01.Chapter.1.mkv"
echo ""

echo "Test 7:"
./parse-filename.sh "Stranger Things - S04E01 - Chapter One - The Hellfire Club.mp4"
echo ""

echo "Test 8:"
./parse-filename.sh "My Show S01E01.avi"
echo ""

echo "Test 9:"
./parse-filename.sh "Game of Thrones S01E01 Winter Is Coming.mp4"
echo ""

echo "Test 10 (expected to fail):"
./parse-filename.sh "This Is Not A TV Show.mp4" || true
echo ""

echo "--- Tests completed ---"
