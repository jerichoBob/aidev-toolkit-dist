#!/bin/bash

# Test markdown link stripping in table output
# This simulates what Claude does when processing the Name column

TEST_INPUT="| v1 | [Company Onboarding](spec-v1-company-onboarding.md) | 34/34 | ✅ Complete |"
EXPECTED_OUTPUT="| v1 | Company Onboarding | 34/34 | ✅ Complete |"

# Apply the regex substitution: extract display text from [text](url)
ACTUAL_OUTPUT=$(echo "$TEST_INPUT" | sed -E 's/\[([^]]+)\]\([^)]+\)/\1/g')

echo "Input:    $TEST_INPUT"
echo "Expected: $EXPECTED_OUTPUT"
echo "Actual:   $ACTUAL_OUTPUT"
echo ""

if [ "$ACTUAL_OUTPUT" = "$EXPECTED_OUTPUT" ]; then
    echo "✅ PASS: Markdown links stripped correctly"
    exit 0
else
    echo "❌ FAIL: Output does not match expected"
    exit 1
fi
