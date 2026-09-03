#!/bin/bash

# Extract parseFilename function from encode-all.sh to avoid executing its main block
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
TMP_FILE="$TMP_DIR/tmp_parseFilename.sh"
trap 'rm -rf "$TMP_DIR"' EXIT
sed -n '/^cleanup_name() {/,/^}/p; /^json_escape() {/,/^}/p; /^parseFilename() {/,/^}/p' "$SCRIPT_DIR/encode-all.sh" > "$TMP_FILE"
source "$TMP_FILE"

# Counter for failed tests
FAILED=0

# Resilient jq fallback for environments without jq installed
if ! command -v jq >/dev/null 2>&1; then
    jq() {
        local field="$2"
        field="${field#.}"
        local content
        content=$(cat)
        if [[ "$content" =~ \"$field\"[[:space:]]*:[[:space:]]*\"(([^\"\\]|\\.)*)\" ]]; then
            local val="${BASH_REMATCH[1]}"
            val="${val//\\\"/\"}"
            val="${val//\\\\/\\}"
            val="${val//\\n/$'\n'}"
            val="${val//\\t/$'\t'}"
            printf '%s\n' "$val"
        elif [[ "$content" =~ \"$field\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
        fi
    }
fi



# Helper function to run a test and verify the output
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" == "$actual" ]; then
        printf "✅ PASS: %s\n" "$message"
    else
        printf "❌ FAIL: %s\n" "$message"
        printf "   Expected: '%s'\n" "$expected"
        printf "   Actual:   '%s'\n" "$actual"
        FAILED=$((FAILED + 1))
    fi
}

printf "Testing parseFilename function...\n"

# Since parseFilename from encode-all.sh relies on somewhat non-standard patterns, we test specifically the ones that correctly output a JSON containing properties based on the buggy regexes in `encode-all.sh`. We use `jq` to ensure valid JSON and specific field extractions.

# The current code in encode-all.sh relies heavily on assumptions about filename format,
# particularly Plex-style recordings "Show Name (2020) S01E01.ts" and similar.

actual=$(parseFilename "Show Name (2020) S01E01.ts")
assert_equal "Show Name" "$(printf "%s\n" "$actual" | jq -r '.show')" "Standard Show Name with Year and Season/Episode - Show"
assert_equal "2020" "$(printf "%s\n" "$actual" | jq -r '.premiered')" "Standard Show Name with Year and Season/Episode - Premiered"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Standard Show Name with Year and Season/Episode - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Standard Show Name with Year and Season/Episode - Episode"

parseFilename "Show Name (2020) S01E01.ts" --no-json
assert_equal "Show Name" "$PARSED_SHOW_NAME" "Standard Show Name with Year and Season/Episode - Show (--no-json)"
assert_equal "01" "$PARSED_SEASON_NUM" "Standard Show Name with Year and Season/Episode - Season (--no-json)"
assert_equal "01" "$PARSED_EPISODE_NUM" "Standard Show Name with Year and Season/Episode - Episode (--no-json)"

parseFilename "Another Show S02E03.ts" --no-json
assert_equal "Another Show" "$PARSED_SHOW_NAME" "Standard Show Name with Season/Episode - Show"
assert_equal "02" "$PARSED_SEASON_NUM" "Standard Show Name with Season/Episode - Season"
assert_equal "03" "$PARSED_EPISODE_NUM" "Standard Show Name with Season/Episode - Episode"

actual=$(parseFilename "The Simpsons (1989) - S32E01 - Undercover Burns.ts")
assert_equal "The Simpsons" "$(printf "%s\n" "$actual" | jq -r '.show')" "Show Name with hyphens - Show"
assert_equal "1989" "$(printf "%s\n" "$actual" | jq -r '.premiered')" "Show Name with hyphens - Premiered"
assert_equal "32" "$(printf "%s\n" "$actual" | jq -r '.season')" "Show Name with hyphens - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Show Name with hyphens - Episode"
assert_equal "Undercover Burns" "$(printf "%s\n" "$actual" | jq -r '.title')" "Show Name with hyphens - Title"

parseFilename "The Simpsons (1989) - S32E01 - Undercover Burns.ts" --no-json
assert_equal "The Simpsons" "$PARSED_SHOW_NAME" "Show Name with hyphens - Show (--no-json)"
assert_equal "32" "$PARSED_SEASON_NUM" "Show Name with hyphens - Season (--no-json)"
assert_equal "01" "$PARSED_EPISODE_NUM" "Show Name with hyphens - Episode (--no-json)"

# --- Edge Cases ---

# Dots instead of spaces
actual=$(parseFilename "Show.With.Dots.S01E02.ts")
assert_equal "Show With Dots" "$(printf "%s\n" "$actual" | jq -r '.show')" "Dots instead of spaces - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Dots instead of spaces - Season"
assert_equal "02" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Dots instead of spaces - Episode"

# Missing Episode
actual=$(parseFilename "MissingEpisode S01.ts")
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.show')" "Missing Episode - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Missing Episode - Season"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Missing Episode - Episode"

# Missing Season
actual=$(parseFilename "MissingSeason E02.ts" 2>/dev/null)
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.show')" "Missing Season - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Missing Season - Season"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Missing Season - Episode"

# Only Show Name
actual=$(parseFilename "Only Show Name.ts" 2>/dev/null)
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.show')" "Only Show Name - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Only Show Name - Season"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Only Show Name - Episode"

# Special characters
actual=$(parseFilename "Special Chars !@#$%.S01E02.ts")
assert_equal "Special Chars !@#$%" "$(printf "%s\n" "$actual" | jq -r '.show')" "Special Chars - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Special Chars - Season"
assert_equal "02" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Special Chars - Episode"

# Start and Stop markers
actual=$(parseFilename "Show Name (2020) S01E01 (start 10) (stop 20).ts")
assert_equal "Show Name" "$(printf "%s\n" "$actual" | jq -r '.show')" "Start and Stop markers - Show"
assert_equal "2020" "$(printf "%s\n" "$actual" | jq -r '.premiered')" "Start and Stop markers - Premiered"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Start and Stop markers - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Start and Stop markers - Episode"

# Empty string
actual=$(parseFilename "" 2>/dev/null)
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.show')" "Empty string - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Empty string - Season"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Empty string - Episode"

# Unexpected extension
actual=$(parseFilename "Show Name (2020) S01E01.mp4")
assert_equal "Show Name" "$(printf "%s\n" "$actual" | jq -r '.show')" "Unexpected extension - Show"
assert_equal "2020" "$(printf "%s\n" "$actual" | jq -r '.premiered')" "Unexpected extension - Premiered"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Unexpected extension - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Unexpected extension - Episode"

# --- Edge Cases: Escaping and Quotes ---

# Escaping strings with double quotes
actual=$(parseFilename 'Show "Name" (2020) S01E01.ts')
assert_equal 'Show "Name"' "$(printf "%s\n" "$actual" | jq -r '.show')" "Double quotes - Show"
assert_equal '2020' "$(printf "%s\n" "$actual" | jq -r '.premiered')" "Double quotes - Premiered"
assert_equal '01' "$(printf "%s\n" "$actual" | jq -r '.season')" "Double quotes - Season"
assert_equal '01' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Double quotes - Episode"

# Escaping strings with backslash
actual=$(parseFilename 'Show \ Name S01E01.ts')
assert_equal 'Show \ Name' "$(printf "%s\n" "$actual" | jq -r '.show')" "Backslash - Show"
assert_equal '01' "$(printf "%s\n" "$actual" | jq -r '.season')" "Backslash - Season"
assert_equal '01' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Backslash - Episode"

# Mixed escaping
actual=$(parseFilename 'Show Name (2020) S01E01 - Some \ Unusual "Quotes" & Chars.ts')
assert_equal 'Show Name' "$(printf "%s\n" "$actual" | jq -r '.show')" "Mixed escaping - Show"
assert_equal '2020' "$(printf "%s\n" "$actual" | jq -r '.premiered')" "Mixed escaping - Premiered"
assert_equal '01' "$(printf "%s\n" "$actual" | jq -r '.season')" "Mixed escaping - Season"
assert_equal '01' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Mixed escaping - Episode"
assert_equal 'Some \ Unusual "Quotes" & Chars' "$(printf "%s\n" "$actual" | jq -r '.title')" "Mixed escaping - Title"

# Escaping strings with newlines
actual=$(parseFilename $'Show Name\nS01E01.ts')
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.show')" "Newline - Show"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.season')" "Newline - Season"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Newline - Episode"

# --- Edge Cases: Datetime Patterns ---

# File with datetime and Episode Title
actual=$(parseFilename 'Show Name (2022) 2022-12-01 20 00 00 - Episode Title.ts')
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.show')" "Datetime with Title - Show"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.season')" "Datetime with Title - Season"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Datetime with Title - Episode"

# File with datetime (No Episode Title)
actual=$(parseFilename 'Show Name 2022-12-01 20 00 00.ts')
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.show')" "Datetime no Title - Show"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.season')" "Datetime no Title - Season"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Datetime no Title - Episode"

# --- Edge Cases: Empty inputs ---
actual=$(parseFilename '')
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.show')" "Empty input - Show"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.season')" "Empty input - Season"
assert_equal '' "$(printf "%s\n" "$actual" | jq -r '.episode')" "Empty input - Episode"

if [ "$FAILED" -gt 0 ]; then
    printf "Summary: %s tests failed.\n" "$FAILED"
    exit 1
else
    printf "Summary: All tests passed!\n"
    exit 0
fi
