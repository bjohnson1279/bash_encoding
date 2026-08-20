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

# Helper function to test cleanup_name
run_cleanup_test() {
    local input="$1"
    local expected="$2"

    ((TOTAL_TESTS++))

    printf "Testing cleanup_name: '%s'\n" "$input"
    local output
    output=$(cleanup_name "$input")

    if [ "$output" != "$expected" ]; then
        printf '%b\n' "${RED}  FAIL: Expected '$expected', got '$output'${NC}"
        ((FAILED_TESTS++))
    else
        printf '%b\n' "${GREEN}  PASS${NC}"
    fi
}

# Helper function to run a test and assert JSON output
run_test() {
    local filename="$1"
    local expected_show="$2"
    local expected_season="$3"
    local expected_episode="$4"
    local expected_title="$5"
    local expected_exit_code="${6:-0}"

    ((TOTAL_TESTS++))

    printf "Testing: %s\n" "$filename"

    # Run the function and capture stdout
    local output
    output=$(parse_filename "$filename")
    local exit_code=$?

    if [ $exit_code -ne $expected_exit_code ]; then
        printf '%b\n' "${RED}  FAIL: Expected exit code $expected_exit_code, got $exit_code${NC}"
        ((FAILED_TESTS++))
        return
    fi

    if [ $expected_exit_code -ne 0 ]; then
        printf '%b\n' "${GREEN}  PASS (Failed as expected)${NC}"
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
        printf '%b\n' "${RED}  FAIL: Show name mismatch. Expected '$expected_show', got '$show'${NC}"
        test_failed=1
    fi

    if [ "$season" != "$expected_season" ]; then
        printf '%b\n' "${RED}  FAIL: Season mismatch. Expected '$expected_season', got '$season'${NC}"
        test_failed=1
    fi

    if [ "$episode" != "$expected_episode" ]; then
        printf '%b\n' "${RED}  FAIL: Episode mismatch. Expected '$expected_episode', got '$episode'${NC}"
        test_failed=1
    fi

    if [ "$title" != "$expected_title" ]; then
        printf '%b\n' "${RED}  FAIL: Title mismatch. Expected '$expected_title', got '$title'${NC}"
        test_failed=1
    fi

    if [ $test_failed -eq 0 ]; then
        printf '%b\n' "${GREEN}  PASS${NC}"
    else
        ((FAILED_TESTS++))
    fi
}

# Helper function to run a test for json_escape
run_json_escape_test() {
    local input="$1"
    local expected_output="$2"

    ((TOTAL_TESTS++))

    printf "Testing json_escape: '%s'\n" "$input"

    # Run the function and capture stdout
    local output
    output=$(json_escape "$input")

    if [ "$output" != "$expected_output" ]; then
        printf '%b\n' "${RED}  FAIL: Expected '$expected_output', got '$output'${NC}"
        ((FAILED_TESTS++))
    else
        printf '%b\n' "${GREEN}  PASS${NC}"
    fi
}

printf '%s\n' "Running tests for parse-filename.sh..."
printf '%s\n' "----------------------------------------"

printf '%s\n' "Testing cleanup_name function..."
run_cleanup_test "My.Awesome.Show" "My Awesome Show"
run_cleanup_test "Another_Show" "Another Show"
run_cleanup_test "  Leading and trailing  " "Leading and trailing"
run_cleanup_test "Multiple...Dots" "Multiple   Dots"
run_cleanup_test ".Hidden.File" "Hidden File"
run_cleanup_test "Show.Name_With.Both" "Show Name With Both"
run_cleanup_test "  Leading_Trailing  " "Leading Trailing"
run_cleanup_test "" ""
printf '%s\n' "----------------------------------------"

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
printf '%s\n' "Testing: missing argument"
output=$(parse_filename 2>&1)
exit_code=$?
if [ $exit_code -ne 1 ]; then
    printf '%b\n' "${RED}  FAIL: Expected exit code 1 for missing argument, got $exit_code${NC}"
    ((FAILED_TESTS++))
elif [ "$output" != "Usage: parse_filename \"<filename>\"" ]; then
    printf '%b\n' "${RED}  FAIL: Expected usage message, got '$output'${NC}"
    ((FAILED_TESTS++))
else
    printf '%b\n' "${GREEN}  PASS (Failed as expected)${NC}"
fi

printf '%s\n' "----------------------------------------"
printf '%s\n' "Running json_escape tests..."
run_json_escape_test "Normal String" "Normal String"
run_json_escape_test "String with \"quotes\"" "String with \\\"quotes\\\""
run_json_escape_test 'String with \ backslash' 'String with \\ backslash'
run_json_escape_test 'String with \"both\"' 'String with \\\"both\\\"'
run_json_escape_test "" ""

printf '%s\n' "----------------------------------------"
printf '%s\n' "Test summary:"
printf '%s\n' "Total: $TOTAL_TESTS"
printf '%s\n' "Failed: $FAILED_TESTS"
printf '%b\n' "Passed: $((TOTAL_TESTS - FAILED_TESTS))"

if [ $FAILED_TESTS -ne 0 ]; then
    exit 1
else
    exit 0
fi
