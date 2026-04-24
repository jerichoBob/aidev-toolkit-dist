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
#   - No API key needed — pure scraper, no external AI calls
#   - --output file= writes to path
#   - --date flag scrapes a specific date
#   - --days N scrapes a multi-day range
#   - --weeks N is shorthand for --days N*7
#   - --all includes read emails
#   - --account list shows logged-in accounts
#   - --account N targets a specific account index

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

# ─── Test 4: no API key needed ────────────────────────────────────────────

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
        if echo "$(uv run "$SCRIPT" --dry-run 2>&1)" | grep -q "Inbox clear"; then
            pass "inbox clear — no file written (expected)"
        else
            fail "--output file= did not create $OUT_FILE (exit=$file_exit)"
        fi
    fi
fi

# ─── Test 6: --date flag ──────────────────────────────────────────────────

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
        if echo "$date_output" | grep -q "Inbox clear\|unread emails\|emails"; then
            pass "--date output shows inbox status for $YESTERDAY"
        else
            fail "--date output unrecognized: $date_output"
        fi
    else
        fail "--date $YESTERDAY exited non-zero: $(echo "$date_output" | tail -3)"
    fi
fi

# ─── Test 7: --days N multi-day range ─────────────────────────────────────

echo ""
echo "Test: --days 3 scrapes last 3 days..."

if ! $CHROME_LIVE; then
    skip_blocked "--days flag" "Chrome CDP not reachable"
else
    set +e
    days_output=$(uv run "$SCRIPT" --dry-run --days 3 2>&1)
    days_exit=$?
    set -e

    if [ "$days_exit" -eq 0 ]; then
        pass "--days 3 exits 0"
        if echo "$days_output" | grep -q "last 3 days\|Inbox clear"; then
            pass "--days 3 output shows correct range label"
        else
            fail "--days 3 output missing range label: $days_output"
        fi
    else
        fail "--days 3 exited non-zero (exit=$days_exit): $days_output"
    fi
fi

# ─── Test 8: --weeks N shorthand ──────────────────────────────────────────

echo ""
echo "Test: --weeks 1 equals --days 7..."

if ! $CHROME_LIVE; then
    skip_blocked "--weeks flag" "Chrome CDP not reachable"
else
    set +e
    weeks_output=$(uv run "$SCRIPT" --dry-run --weeks 1 2>&1)
    weeks_exit=$?
    set -e

    if [ "$weeks_exit" -eq 0 ]; then
        pass "--weeks 1 exits 0"
        if echo "$weeks_output" | grep -q "last 7 days\|Inbox clear"; then
            pass "--weeks 1 shows 'last 7 days' label"
        else
            fail "--weeks 1 output missing '7 days' label: $weeks_output"
        fi
    else
        fail "--weeks 1 exited non-zero (exit=$weeks_exit): $weeks_output"
    fi
fi

# ─── Test 9: --all includes read emails ───────────────────────────────────

echo ""
echo "Test: --all includes read emails..."

if ! $CHROME_LIVE; then
    skip_blocked "--all flag" "Chrome CDP not reachable"
else
    set +e
    all_output=$(uv run "$SCRIPT" --dry-run --all 2>&1)
    all_exit=$?
    set -e

    if [ "$all_exit" -eq 0 ]; then
        pass "--all exits 0"
        # Should show "emails" not "unread emails" in label
        if echo "$all_output" | grep -q "Inbox clear\|emails"; then
            pass "--all output shows inbox status"
        else
            fail "--all output unrecognized: $all_output"
        fi
    else
        fail "--all exited non-zero (exit=$all_exit): $all_output"
    fi
fi

# ─── Test 10: --account list shows logged-in accounts ────────────────────

echo ""
echo "Test: --account list shows logged-in Gmail accounts..."

if ! $CHROME_LIVE; then
    skip_blocked "--account list" "Chrome CDP not reachable"
else
    set +e
    acct_output=$(uv run "$SCRIPT" --account list 2>&1)
    acct_exit=$?
    set -e

    if [ "$acct_exit" -eq 0 ]; then
        pass "--account list exits 0"
        if echo "$acct_output" | grep -q "0:"; then
            pass "--account list shows at least account 0"
        else
            fail "--account list output missing account entries: $acct_output"
        fi
    else
        fail "--account list exited non-zero (exit=$acct_exit): $acct_output"
    fi
fi

# ─── Test 11: --account 0 explicit default account ───────────────────────

echo ""
echo "Test: --account 0 targets default account..."

if ! $CHROME_LIVE; then
    skip_blocked "--account 0" "Chrome CDP not reachable"
else
    set +e
    acct0_output=$(uv run "$SCRIPT" --dry-run --account 0 2>&1)
    acct0_exit=$?
    set -e

    if [ "$acct0_exit" -eq 0 ]; then
        pass "--account 0 exits 0"
    else
        fail "--account 0 exited non-zero (exit=$acct0_exit): $acct0_output"
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
