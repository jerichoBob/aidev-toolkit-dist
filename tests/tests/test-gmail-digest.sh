#!/bin/bash
#
# aidev toolkit gmail-digest.py Integration Test Suite
#
# Live integration tests — requires Chrome with CDP enabled.
# Tests that need live dependencies are marked blocked when unavailable.
# No mocks. All tests invoke the real script against real services.
#
# Coverage:
#   - No args exits cleanly (no traceback)
#   - --check reports Chrome reachability
#   - --dry-run scrapes inbox, shows email list or inbox-clear
#   - No API key needed — script is a pure scraper, no external AI calls

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

# ── Prereq check ──────────────────────────────────────────────────────────

CHROME_LIVE=false

if command -v browser-harness &>/dev/null; then
    if uv run "$SCRIPT" --check 2>/dev/null; then
        CHROME_LIVE=true
    fi
fi

# ─── Test 1: no args exits cleanly, no Python traceback ───────────────────

echo ""
echo "Test: no args runs without crashing..."

set +e
output=$(uv run "$SCRIPT" 2>&1)
exit_code=$?
set -e

if echo "$output" | grep -q "Traceback\|SyntaxError"; then
    fail "script produced a Python traceback: $output"
else
    pass "script exits cleanly (no Python traceback)"
fi

# ─── Test 2: --check reports Chrome status ────────────────────────────────

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

# ─── Test 3: --dry-run scrapes inbox ──────────────────────────────────────

echo ""
echo "Test: --dry-run scrapes inbox (live Chrome)..."

if ! $CHROME_LIVE; then
    skip_blocked "--dry-run against real Gmail inbox" "Chrome CDP not reachable"
else
    set +e
    dry_output=$(uv run "$SCRIPT" --dry-run 2>&1)
    dry_exit=$?
    set -e

    if [ "$dry_exit" -eq 0 ]; then
        pass "--dry-run exits 0"
        if echo "$dry_output" | grep -q "Inbox clear\|unread emails"; then
            pass "--dry-run output shows inbox status"
        else
            fail "--dry-run output unrecognized: $dry_output"
        fi
    else
        fail "--dry-run exited non-zero (exit=$dry_exit): $dry_output"
    fi
fi

# ─── Test 4: no API key needed — script is a pure scraper ─────────────────

echo ""
echo "Test: script works with ANTHROPIC_API_KEY explicitly unset..."

if ! $CHROME_LIVE; then
    skip_blocked "no-API-key scrape" "Chrome CDP not reachable"
else
    set +e
    no_key_output=$(ANTHROPIC_API_KEY="" uv run "$SCRIPT" --dry-run 2>&1)
    no_key_exit=$?
    set -e

    if [ "$no_key_exit" -eq 0 ]; then
        pass "exits 0 with ANTHROPIC_API_KEY unset"
    else
        if echo "$no_key_output" | grep -qi "ANTHROPIC_API_KEY"; then
            fail "script requires ANTHROPIC_API_KEY — it should not"
        else
            fail "unexpected failure (exit=$no_key_exit): $no_key_output"
        fi
    fi
fi

# ─── Test 5: --output file= writes to path ────────────────────────────────

echo ""
echo "Test: --output file= writes email list to path..."

if ! $CHROME_LIVE; then
    skip_blocked "--output file= test" "Chrome CDP not reachable"
else
    OUT_FILE="$TEST_HOME/emails.txt"

    set +e
    uv run "$SCRIPT" --dry-run --output "file=$OUT_FILE" 2>&1
    file_exit=$?
    set -e

    if [ -f "$OUT_FILE" ]; then
        pass "--output file= created the output file"
        if grep -q "unread emails\|Inbox clear" "$OUT_FILE" 2>/dev/null; then
            pass "output file contains expected content"
        else
            fail "output file content unexpected: $(head -3 "$OUT_FILE")"
        fi
    else
        # Script may exit 0 with no file if inbox is clear (no emails = no file)
        if echo "$(uv run "$SCRIPT" --dry-run 2>&1)" | grep -q "Inbox clear"; then
            pass "inbox clear — no file written (expected)"
        else
            fail "--output file= did not create $OUT_FILE (exit=$file_exit)"
        fi
    fi
fi

# ─── Test 6: --date flag with yesterday's date ────────────────────────────

echo ""
echo "Test: --date flag with yesterday's date..."

if ! $CHROME_LIVE; then
    skip_blocked "--date flag" "Chrome CDP not reachable"
else
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)

    set +e
    date_output=$(uv run "$SCRIPT" --dry-run --date "$YESTERDAY" 2>&1)
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
