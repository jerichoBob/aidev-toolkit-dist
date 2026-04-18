#!/bin/bash
#
# aidev toolkit Test Runner
#
# Finds and executes all test-*.sh scripts, aggregates results
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
TESTS_RUN=0
TESTS_FAILED=0

echo ""
echo "aidev toolkit Test Runner"
echo "========================"
echo ""

# Find all test scripts
TEST_SCRIPTS=$(find "$SCRIPT_DIR" -name "test-*.sh" -type f | sort)

if [ -z "$TEST_SCRIPTS" ]; then
    echo "No test scripts found in $SCRIPT_DIR"
    exit 1
fi

# Run each test script
while IFS= read -r test_script; do
    test_name=$(basename "$test_script" .sh)
    echo "Running $test_name..."
    echo "----------------------------------------"

    ((TESTS_RUN++)) || true

    if "$test_script"; then
        echo ""
        echo "✓ $test_name PASSED"
    else
        echo ""
        echo "✗ $test_name FAILED"
        ((TESTS_FAILED++)) || true
    fi

    echo "========================================"
    echo ""
done <<< "$TEST_SCRIPTS"

# Summary
echo ""
echo "========================"
echo "Test Suite Summary"
echo "========================"
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $((TESTS_RUN - TESTS_FAILED))"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
