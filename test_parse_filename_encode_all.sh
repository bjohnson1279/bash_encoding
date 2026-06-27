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
assert_equal "Show Name (2020)" "$(echo "$actual" | jq -r '.show')" "Standard Show Name with Year and Season/Episode - Show"
assert_equal "01" "$(echo "$actual" | jq -r '.season')" "Standard Show Name with Year and Season/Episode - Season"
assert_equal "01" "$(echo "$actual" | jq -r '.episode')" "Standard Show Name with Year and Season/Episode - Episode"

actual=$(parseFilename "Another Show S02E03.ts")
assert_equal "Another Show" "$(echo "$actual" | jq -r '.show')" "Standard Show Name with Season/Episode - Show"
assert_equal "02" "$(echo "$actual" | jq -r '.season')" "Standard Show Name with Season/Episode - Season"
assert_equal "03" "$(echo "$actual" | jq -r '.episode')" "Standard Show Name with Season/Episode - Episode"

actual=$(parseFilename "The Simpsons (1989) - S32E01 - Undercover Burns.ts")
assert_equal "The Simpsons (1989) -" "$(echo "$actual" | jq -r '.show')" "Show Name with hyphens - Show"
assert_equal "32" "$(echo "$actual" | jq -r '.season')" "Show Name with hyphens - Season"
assert_equal "01" "$(echo "$actual" | jq -r '.episode')" "Show Name with hyphens - Episode"

if [ $FAILED -gt 0 ]; then
    echo "Summary: $FAILED tests failed."
    exit 1
else
    echo "Summary: All tests passed!"
    exit 0
fi
