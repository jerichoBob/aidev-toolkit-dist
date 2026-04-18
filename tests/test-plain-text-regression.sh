#!/bin/bash

# Test that plain text (no markdown links) is unchanged
# This ensures no regression when Name column has plain text

TEST_INPUT="| v1 | Core Foundation | 7/7 | ✅ Complete |"
EXPECTED_OUTPUT="| v1 | Core Foundation | 7/7 | ✅ Complete |"

# Apply the regex substitution (should have no effect on plain text)
ACTUAL_OUTPUT=$(echo "$TEST_INPUT" | sed -E 's/\[([^]]+)\]\([^)]+\)/\1/g')

echo "Input:    $TEST_INPUT"
echo "Expected: $EXPECTED_OUTPUT"
echo "Actual:   $ACTUAL_OUTPUT"
echo ""

if [ "$ACTUAL_OUTPUT" = "$EXPECTED_OUTPUT" ]; then
    echo "✅ PASS: Plain text unchanged (no regression)"
    exit 0
else
    echo "❌ FAIL: Plain text was modified"
    exit 1
fi
