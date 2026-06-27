#!/bin/bash

# Extract parseShowTitle function from encode-all.sh to avoid executing its main block
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_FILE="${SCRIPT_DIR}/tmp_parseShowTitle.sh"
trap 'rm -f "$TMP_FILE"' EXIT
sed -n '/^parseShowTitle() {/,/^}/p' "$SCRIPT_DIR/encode-all.sh" > "$TMP_FILE"
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

echo "Testing parseShowTitle function..."

# Test standard cases
actual=$(parseShowTitle "Show Name (2020) S01E01.ts")
assert_equal "Show Name (2020)" "$actual" "Standard Show Name with Year and Season/Episode"

actual=$(parseShowTitle "Another Show S02E03.ts")
assert_equal "Another Show" "$actual" "Standard Show Name with Season/Episode"

actual=$(parseShowTitle "The Simpsons (1989) - S32E01 - Undercover Burns.ts")
assert_equal "The Simpsons (1989) -" "$actual" "Show Name with hyphens"

actual=$(parseShowTitle "Saturday Night Live (1975) - S46E04 - Adele; H.E.R..ts")
assert_equal "Saturday Night Live (1975) -" "$actual" "Show Name with complex episode string"

# A basic file without any expected patterns to see what happens
actual=$(parseShowTitle "Show Name.ts")
assert_equal "Show Name" "$actual" "Show Name with no extra parts"

# Clean up
rm tmp_parseShowTitle.sh

if [ $FAILED -gt 0 ]; then
    echo "Summary: $FAILED tests failed."
    exit 1
else
    echo "Summary: All tests passed!"
    exit 0
fi
