#!/bin/bash
#
# aidev toolkit test-browser-harness-tab-reuse.sh Test Suite
#
# Verifies spec v119: /browser-harness reuses a matching open Chrome tab
# before opening a new one. Static assertions on the skill, plus a live check
# against real Chrome over CDP (marked BLOCKED if unavailable — never mocked).
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$REPO_DIR/skills/browser-harness.md"
HELPERS="$HOME/.local/share/uv/tools/browser-harness/lib/python3.12/site-packages/browser_harness/helpers.py"

PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

echo ""
echo "aidev toolkit test-browser-harness-tab-reuse.sh Tests"
echo "====================================================="

if [ ! -f "$SKILL" ]; then
    echo "  ✗ skills/browser-harness.md not found"
    exit 1
fi

# ─── Static assertions (AC-1, AC-2, AC-3, AC-4, AC-5, AC-7) ──────────────────

echo ""
echo "Test: skill contains tab-matching step..."
grep -q "def find_matching_tabs" "$SKILL" && pass "find_matching_tabs defined" || fail "find_matching_tabs missing"
grep -q "list_tabs(include_chrome=False)" "$SKILL" && pass "uses list_tabs(include_chrome=False)" || fail "list_tabs call missing"
grep -q "switch_tab(targetId)" "$SKILL" && pass "switch_tab branch present" || fail "switch_tab branch missing"
grep -q "new_tab(url)" "$SKILL" && pass "new_tab branch present" || fail "new_tab branch missing"

echo ""
echo "Test: multi-match asks the user (AC-3)..."
grep -E '^allowed-tools:.*AskUserQuestion' "$SKILL" >/dev/null && pass "AskUserQuestion in allowed-tools" || fail "AskUserQuestion not allowed"
grep -q "Two or more matches" "$SKILL" && pass "multi-match rule present" || fail "multi-match rule missing"

echo ""
echo "Test: stale-tab fallback and safety rules (AC-4, AC-5, AC-7)..."
grep -q "switch_tab. raises" "$SKILL" && pass "stale-tab fallback documented" || fail "stale-tab fallback missing"
grep -q "never build a regex" "$SKILL" && pass "no-regex rule documented" || fail "no-regex rule missing"
grep -q "never close a tab the harness did not create" "$SKILL" && pass "no-close rule documented" || fail "no-close rule missing"
grep -q "reused or created" "$SKILL" && pass "reuse/create reporting documented" || fail "reporting rule missing"

# ─── AC-6: helper names exist in installed helpers.py ────────────────────────

echo ""
echo "Test: no nonexistent helpers referenced (AC-6)..."
if grep -nE '(^|[^_a-z])goto\(|[^_a-z]screenshot\(' "$SKILL" >/dev/null; then
    fail "skill references goto( or screenshot( (nonexistent helpers)"
else
    pass "no goto( / screenshot( references"
fi

if [ -f "$HELPERS" ]; then
    for fn in goto_url capture_screenshot list_tabs switch_tab new_tab; do
        if grep -q "^def $fn(" "$HELPERS"; then
            pass "helpers.py defines $fn"
        else
            fail "helpers.py does not define $fn"
        fi
    done
else
    skip_blocked "helper-name check against helpers.py" "browser-harness not installed at $HELPERS"
fi

# ─── Live check: real Chrome over CDP ────────────────────────────────────────

echo ""
echo "Test: find_matching_tabs against real Chrome..."

if ! command -v browser-harness >/dev/null 2>&1; then
    skip_blocked "live find_matching_tabs" "browser-harness not installed"
elif ! browser-harness <<'PY' >/dev/null 2>&1
print(page_info())
PY
then
    skip_blocked "live find_matching_tabs" "cannot attach to Chrome over CDP"
else
    # Extract the snippet's function from the skill so the test exercises the real text.
    FUNC=$(awk '/^def find_matching_tabs/{c=1} c&&/^$/{exit} c{print}' "$SKILL")
    OUT=$(browser-harness <<PY 2>&1
$FUNC
import time
a = new_tab("data:text/html,<title>aidtabreuse-alpha</title>")
time.sleep(1)
b = new_tab("data:text/html,<title>aidtabreuse-beta</title>")
time.sleep(1)
ma = find_matching_tabs("AIDTABREUSE-ALPHA")
mb = find_matching_tabs("aidtabreuse-beta")
none = find_matching_tabs("aidtabreuse-gamma")
both = find_matching_tabs("aidtabreuse")
print("RESULT", len(ma), len(mb), len(none), len(both), ma[0]["targetId"] == a if ma else None, mb[0]["targetId"] == b if mb else None)
for t in (ma + mb):
    try: close_tab(t["targetId"])
    except Exception as e: print("CLEANUP_FAIL", e)
PY
)
    if echo "$OUT" | grep -q "RESULT 1 1 0 2 True True"; then
        pass "returns exact tab per query; none for no match; two for shared prefix"
    else
        fail "unexpected live result: $(echo "$OUT" | tail -3)"
    fi
fi

echo ""
echo "====================================================="
echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "✗ test-browser-harness-tab-reuse FAILED"
    exit 1
fi
echo "✓ test-browser-harness-tab-reuse PASSED"
