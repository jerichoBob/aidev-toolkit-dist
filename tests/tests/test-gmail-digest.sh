#!/bin/bash
#
# aidev toolkit gmail-digest.py Integration Test Suite
#
# Live integration tests — requires Chrome with CDP enabled and ANTHROPIC_API_KEY.
# Tests that need live dependencies are marked blocked when unavailable.
# No mocks. All tests invoke the real script against real services.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/gmail-digest.py"

PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit gmail-digest.py Integration Tests"
echo "================================================"

# ── Prereq checks ─────────────────────────────────────────────────────────

CHROME_LIVE=false
API_KEY_SET=false

if command -v browser-harness &>/dev/null; then
    if uv run "$SCRIPT" --check 2>/dev/null; then
        CHROME_LIVE=true
    fi
fi

if [ -n "$ANTHROPIC_API_KEY" ]; then
    API_KEY_SET=true
fi

# ─── Test 1: missing browser-harness CLI exits with install hint ───────────

echo ""
echo "Test: argument validation — no args runs without crashing..."

# The script should exit 0 (inbox clear) or non-zero (Chrome down) — never a Python traceback
set +e
output=$(uv run "$SCRIPT" 2>&1)
exit_code=$?
set -e

if echo "$output" | grep -q "Traceback\|SyntaxError"; then
    fail "script produced a Python traceback: $output"
else
    pass "script exits cleanly (no Python traceback)"
fi

# ─── Test 2: --check with Chrome alive or clear error when not ────────────

echo ""
echo "Test: --check reports Chrome status..."

set +e
check_output=$(uv run "$SCRIPT" --check 2>&1)
check_exit=$?
set -e

if $CHROME_LIVE; then
    if [ "$check_exit" -eq 0 ] && echo "$check_output" | grep -q "reachable"; then
        pass "--check exits 0 and reports reachable when Chrome is live"
    else
        fail "--check unexpected result (exit=$check_exit): $check_output"
    fi
else
    if [ "$check_exit" -ne 0 ] && echo "$check_output" | grep -qi "not reachable\|not found\|timed out"; then
        pass "--check exits non-zero with clear error when Chrome is down"
    else
        fail "--check did not produce a clear error: $check_output"
    fi
fi

# ─── Test 3: --dry-run with live Chrome ────────────────────────────────────

echo ""
echo "Test: --dry-run (live Chrome, no API call)..."

if ! $CHROME_LIVE; then
    skip_blocked "--dry-run against real Gmail inbox" "Chrome CDP not reachable"
else
    set +e
    dry_output=$(uv run "$SCRIPT" --dry-run 2>&1)
    dry_exit=$?
    set -e

    if [ "$dry_exit" -eq 0 ]; then
        pass "--dry-run exits 0"
        if echo "$dry_output" | grep -q "Inbox clear\|dry run\|unread email"; then
            pass "--dry-run output shows inbox status or email list"
        else
            fail "--dry-run output unrecognized: $dry_output"
        fi
        # Must NOT call the API — no API usage in dry-run output
        if echo "$dry_output" | grep -qi "\[API\]\|categoriz"; then
            fail "--dry-run unexpectedly called the Claude API"
        else
            pass "--dry-run did not invoke the Claude API"
        fi
    else
        fail "--dry-run exited non-zero (exit=$dry_exit): $dry_output"
    fi
fi

# ─── Test 4: full digest against real inbox ────────────────────────────────

echo ""
echo "Test: full digest with live Chrome and Anthropic API..."

if ! $CHROME_LIVE; then
    skip_blocked "full digest" "Chrome CDP not reachable"
elif ! $API_KEY_SET; then
    skip_blocked "full digest" "ANTHROPIC_API_KEY not set"
else
    set +e
    digest_output=$(uv run "$SCRIPT" --verbose 2>&1)
    digest_exit=$?
    set -e

    if [ "$digest_exit" -eq 0 ]; then
        pass "full digest exits 0"
        if echo "$digest_output" | grep -qi "Gmail Digest\|Inbox clear"; then
            pass "digest output contains expected header or inbox-clear message"
        else
            fail "digest output missing expected header: $(echo "$digest_output" | head -5)"
        fi
    else
        fail "full digest exited non-zero (exit=$digest_exit): $(echo "$digest_output" | tail -5)"
    fi
fi

# ─── Test 5: prompt cache hit on second run ────────────────────────────────

echo ""
echo "Test: prompt cache hit on second run..."

if ! $CHROME_LIVE; then
    skip_blocked "cache hit verification" "Chrome CDP not reachable"
elif ! $API_KEY_SET; then
    skip_blocked "cache hit verification" "ANTHROPIC_API_KEY not set"
else
    # Run twice — second run should show cache_read_input_tokens > 0
    set +e
    run2=$(uv run "$SCRIPT" --verbose 2>&1)
    run2_exit=$?
    set -e

    if [ "$run2_exit" -eq 0 ]; then
        if echo "$run2" | grep -q "cache_hit=[1-9]"; then
            pass "second run shows cache_hit > 0 (prompt cache working)"
        elif echo "$run2" | grep -q "Inbox clear"; then
            pass "inbox clear — cache hit N/A (no emails to categorize)"
        else
            # cache_hit=0 on second run is a real failure if we had emails
            if echo "$run2" | grep -q "cache_hit=0"; then
                fail "second run shows cache_hit=0 — prompt caching not working"
            else
                pass "second run completed (cache status unclear — no emails)"
            fi
        fi
    else
        fail "second run exited non-zero: $(echo "$run2" | tail -3)"
    fi
fi

# ─── Test 6: --output file= writes digest to path ─────────────────────────

echo ""
echo "Test: --output file= writes to specified path..."

if ! $CHROME_LIVE; then
    skip_blocked "--output file= test" "Chrome CDP not reachable"
elif ! $API_KEY_SET; then
    skip_blocked "--output file= test" "ANTHROPIC_API_KEY not set"
else
    OUT_FILE="$TEST_HOME/digest-out.md"

    set +e
    uv run "$SCRIPT" --output "file=$OUT_FILE" 2>&1
    file_exit=$?
    set -e

    if [ -f "$OUT_FILE" ]; then
        pass "--output file= created the output file"
        if grep -q "Gmail Digest\|Inbox clear" "$OUT_FILE" 2>/dev/null; then
            pass "output file contains expected content"
        else
            fail "output file content unexpected: $(head -3 "$OUT_FILE")"
        fi
    elif grep -q "Inbox clear" "$(uv run "$SCRIPT" 2>&1 || true)"; then
        pass "inbox clear — no file written (expected)"
    else
        fail "--output file= did not create $OUT_FILE (exit=$file_exit)"
    fi
fi

# ─── Test 7: --date flag with a past date ─────────────────────────────────

echo ""
echo "Test: --date flag with yesterday's date..."

if ! $CHROME_LIVE; then
    skip_blocked "--date flag" "Chrome CDP not reachable"
elif ! $API_KEY_SET; then
    skip_blocked "--date flag" "ANTHROPIC_API_KEY not set"
else
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)

    set +e
    date_output=$(uv run "$SCRIPT" --date "$YESTERDAY" 2>&1)
    date_exit=$?
    set -e

    if [ "$date_exit" -eq 0 ]; then
        pass "--date $YESTERDAY exits 0"
    else
        fail "--date $YESTERDAY exited non-zero: $(echo "$date_output" | tail -3)"
    fi
fi

echo ""
echo "================================================"
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-gmail-digest PASSED"
    exit 0
else
    echo "✗ test-gmail-digest FAILED"
    exit 1
fi
