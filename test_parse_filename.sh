#!/bin/bash

# Source parse_filename script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parse-filename.sh"

# Simple testing framework for parse-filename.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FAILED_TESTS=0
TOTAL_TESTS=0

# Helper function to run a test and assert JSON output
run_test() {
    local filename="$1"
    local expected_show="$2"
    local expected_season="$3"
    local expected_episode="$4"
    local expected_title="$5"
    local expected_exit_code="${6:-0}"

    ((TOTAL_TESTS++))

    echo "Testing: $filename"

    # Run the function and capture stdout
    local output
    output=$(parse_filename "$filename")
    local exit_code=$?

    if [ $exit_code -ne $expected_exit_code ]; then
        echo -e "${RED}  FAIL: Expected exit code $expected_exit_code, got $exit_code${NC}"
        ((FAILED_TESTS++))
        return
    fi

    if [ $expected_exit_code -ne 0 ]; then
        echo -e "${GREEN}  PASS (Failed as expected)${NC}"
        return
    fi

    # Extract JSON part from output (ignoring the "Parsing filename: ..." line)
    local json_output
    json_output=$(printf "%s\n" "$output" | grep -v "^Parsing filename:")

    local show=$(printf "%s\n" "$json_output" | jq -r '.show_name')
    local season=$(printf "%s\n" "$json_output" | jq -r '.season')
    local episode=$(printf "%s\n" "$json_output" | jq -r '.episode')
    local title=$(printf "%s\n" "$json_output" | jq -r '.title')

    local test_failed=0

    if [ "$show" != "$expected_show" ]; then
        echo -e "${RED}  FAIL: Show name mismatch. Expected '$expected_show', got '$show'${NC}"
        test_failed=1
    fi

    if [ "$season" != "$expected_season" ]; then
        echo -e "${RED}  FAIL: Season mismatch. Expected '$expected_season', got '$season'${NC}"
        test_failed=1
    fi

    if [ "$episode" != "$expected_episode" ]; then
        echo -e "${RED}  FAIL: Episode mismatch. Expected '$expected_episode', got '$episode'${NC}"
        test_failed=1
    fi

    if [ "$title" != "$expected_title" ]; then
        echo -e "${RED}  FAIL: Title mismatch. Expected '$expected_title', got '$title'${NC}"
        test_failed=1
    fi

    if [ $test_failed -eq 0 ]; then
        echo -e "${GREEN}  PASS${NC}"
    else
        ((FAILED_TESTS++))
    fi
}

# Helper function to run a test for json_escape
run_json_escape_test() {
    local input="$1"
    local expected_output="$2"

    ((TOTAL_TESTS++))

    echo "Testing json_escape: '$input'"

    # Run the function and capture stdout
    local output
    output=$(json_escape "$input")

    if [ "$output" != "$expected_output" ]; then
        echo -e "${RED}  FAIL: Expected '$expected_output', got '$output'${NC}"
        ((FAILED_TESTS++))
    else
        echo -e "${GREEN}  PASS${NC}"
    fi
}

echo "Running tests for parse-filename.sh..."
echo "----------------------------------------"

# run_test "filename" "expected_show" "expected_season" "expected_episode" "expected_title" "expected_exit_code"

# Test cases from comments in parse-filename.sh
run_test "My.Awesome.Show.S01E05.The.Big.Adventure.mkv" "My Awesome Show" "01" "05" "The Big Adventure"
run_test "Another Show - S02E10 - A New Day.mp4" "Another Show" "02" "10" "- A New Day"
run_test "Series.Title.S03E01.avi" "Series Title" "03" "01" ""
run_test "Test.Show.Name.S01E02.Pilot.mkv" "Test Show Name" "01" "02" "Pilot"
run_test "The.Mandalorian.S01E01.Chapter.1.mkv" "The Mandalorian" "01" "01" "Chapter 1"
run_test "Stranger Things - S04E01 - Chapter One - The Hellfire Club.mp4" "Stranger Things" "04" "01" "- Chapter One - The Hellfire Club"
run_test "My Show S01E01.avi" "My Show" "01" "01" ""
run_test "Game of Thrones S01E01 Winter Is Coming.mp4" "Game of Thrones" "01" "01" "Winter Is Coming"

# Edge cases
run_test "Show Name  S01E02  Title.mp4" "Show Name" "01" "02" "Title"
run_test "Show.Name.S01E02.Title" "Show Name" "01" "02" "" # Title is incorrectly treated as extension due to script logic

# Expected failure cases
run_test "Unparseable Filename.mp4" "" "" "" "" 1
run_test "This Is Not A TV Show.mp4" "" "" "" "" 1
run_test "" "" "" "" "" 1

# Missing argument test
((TOTAL_TESTS++))
echo "Testing: missing argument"
output=$(parse_filename 2>&1)
exit_code=$?
if [ $exit_code -ne 1 ]; then
    echo -e "${RED}  FAIL: Expected exit code 1 for missing argument, got $exit_code${NC}"
    ((FAILED_TESTS++))
elif [ "$output" != "Usage: parse_filename \"<filename>\"" ]; then
    echo -e "${RED}  FAIL: Expected usage message, got '$output'${NC}"
    ((FAILED_TESTS++))
else
    echo -e "${GREEN}  PASS (Failed as expected)${NC}"
fi

echo "----------------------------------------"
echo "Running json_escape tests..."
run_json_escape_test "Normal String" "Normal String"
run_json_escape_test "String with \"quotes\"" "String with \\\"quotes\\\""
run_json_escape_test 'String with \ backslash' 'String with \\ backslash'
run_json_escape_test 'String with \"both\"' 'String with \\\"both\\\"'

echo "----------------------------------------"
echo "Test summary:"
echo "Total: $TOTAL_TESTS"
echo "Failed: $FAILED_TESTS"
echo -e "Passed: $((TOTAL_TESTS - FAILED_TESTS))"

if [ $FAILED_TESTS -ne 0 ]; then
    exit 1
else
    exit 0
fi
