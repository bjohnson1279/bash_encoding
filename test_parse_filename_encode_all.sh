#!/bin/bash

# Extract parseFilename function from encode-all.sh to avoid executing its main block
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_FILE="${SCRIPT_DIR}/tmp_parseFilename.sh"
trap 'rm -f "$TMP_FILE"' EXIT
sed -n '/^parseFilename() {/,/^}/p' "$SCRIPT_DIR/encode-all.sh" > "$TMP_FILE"
source "$TMP_FILE"

# Counter for failed tests
FAILED=0

# Helper function to run a test and verify the output
assert_equal() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" == "$actual" ]; then
        echo "✅ PASS: $message"
    else
        echo "❌ FAIL: $message"
        echo "   Expected: '$expected'"
        echo "   Actual:   '$actual'"
        FAILED=$((FAILED + 1))
    fi
}

echo "Testing parseFilename function..."

# Since parseFilename from encode-all.sh relies on somewhat non-standard patterns, we test specifically the ones that correctly output a JSON containing properties based on the buggy regexes in `encode-all.sh`. We use `jq` to ensure valid JSON and specific field extractions.

# The current code in encode-all.sh relies heavily on assumptions about filename format,
# particularly Plex-style recordings "Show Name (2020) S01E01.ts" and similar.

actual=$(parseFilename "Show Name (2020) S01E01.ts")
assert_equal "Show Name (2020)" "$(printf "%s\n" "$actual" | jq -r '.show')" "Standard Show Name with Year and Season/Episode - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Standard Show Name with Year and Season/Episode - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Standard Show Name with Year and Season/Episode - Episode"

actual=$(parseFilename "Another Show S02E03.ts")
assert_equal "Another Show" "$(printf "%s\n" "$actual" | jq -r '.show')" "Standard Show Name with Season/Episode - Show"
assert_equal "02" "$(printf "%s\n" "$actual" | jq -r '.season')" "Standard Show Name with Season/Episode - Season"
assert_equal "03" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Standard Show Name with Season/Episode - Episode"

actual=$(parseFilename "The Simpsons (1989) - S32E01 - Undercover Burns.ts")
assert_equal "The Simpsons (1989) -" "$(printf "%s\n" "$actual" | jq -r '.show')" "Show Name with hyphens - Show"
assert_equal "32" "$(printf "%s\n" "$actual" | jq -r '.season')" "Show Name with hyphens - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Show Name with hyphens - Episode"

# --- Edge Cases (Asserting current "quirky" behavior) ---

# Dots instead of spaces
actual=$(parseFilename "Show.With.Dots.S01E02.ts")
assert_equal "Show.With.Dots.S01E02 \\([0-9]*}" "$(printf "%s\n" "$actual" | jq -r '.show')" "Dots instead of spaces - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Dots instead of spaces - Season"
assert_equal "0102" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Dots instead of spaces - Episode"

# Missing Episode
actual=$(parseFilename "MissingEpisode S01.ts")
assert_equal "MissingEpisode" "$(printf "%s\n" "$actual" | jq -r '.show')" "Missing Episode - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Missing Episode - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Missing Episode - Episode"

# Missing Season
# parseFilename prints a syntax error on line 59 for this case ([: ==: unary operator expected),
# so we suppress stderr to let the test run cleanly.
actual=$(parseFilename "MissingSeason E02.ts" 2>/dev/null)
assert_equal "MissingSeason E02 \\([0-9]*}" "$(printf "%s\n" "$actual" | jq -r '.show')" "Missing Season - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Missing Season - Season"
assert_equal "02" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Missing Season - Episode"

# Only Show Name
actual=$(parseFilename "Only Show Name.ts" 2>/dev/null)
assert_equal "Only Show Name \\([0-9]*}" "$(printf "%s\n" "$actual" | jq -r '.show')" "Only Show Name - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Only Show Name - Season"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Only Show Name - Episode"

# Special characters
actual=$(parseFilename "Special Chars !@#$%.S01E02.ts")
assert_equal "Special Chars !@#$%.S01E02 \\([0-9]*}" "$(printf "%s\n" "$actual" | jq -r '.show')" "Special Chars - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Special Chars - Season"
assert_equal "0102" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Special Chars - Episode"

# Start and Stop markers
# Note: The underlying regex is quirky. (start...) and (stop...) get stripped entirely from $FILE,
# and they end up absorbed into the 'date' field or title artifacts. We assert the current baseline
# behavior rather than fix the function here.
actual=$(parseFilename "Show Name (2020) S01E01 (start 10) (stop 20).ts")
assert_equal "Show Name (2020)" "$(printf "%s\n" "$actual" | jq -r '.show')" "Start and Stop markers - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Start and Stop markers - Season"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Start and Stop markers - Episode"
assert_equal "S01E01 (start 10) (stop 20)" "$(printf "%s\n" "$actual" | jq -r '.date')" "Start and Stop markers - Date Field Capture"

# Empty string
actual=$(parseFilename "" 2>/dev/null)
assert_equal "\\([0-9]*}" "$(printf "%s\n" "$actual" | jq -r '.show')" "Empty string - Show"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.season')" "Empty string - Season"
assert_equal "" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Empty string - Episode"

# Unexpected extension
actual=$(parseFilename "Show Name (2020) S01E01.mp4")
assert_equal "Show Name (2020)" "$(printf "%s\n" "$actual" | jq -r '.show')" "Unexpected extension - Show"
assert_equal "01" "$(printf "%s\n" "$actual" | jq -r '.season')" "Unexpected extension - Season"
assert_equal "014" "$(printf "%s\n" "$actual" | jq -r '.episode')" "Unexpected extension - Episode"

if [ $FAILED -gt 0 ]; then
    echo "Summary: $FAILED tests failed."
    exit 1
else
    echo "Summary: All tests passed!"
    exit 0
fi
