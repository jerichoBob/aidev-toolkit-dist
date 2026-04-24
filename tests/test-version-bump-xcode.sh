#!/bin/bash
#
# aidev toolkit version-bump Xcode Info.plist Tests
#
# Validates the Info.plist variable-substitution logic that version-bump
# instructs Claude to run via plistlib. Tests use fixture plist files in
# isolated temp directories — no real Xcode project required.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
skip_blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

TEST_HOME=$(mktemp -d)
cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# Python logic extracted from skills/version-bump.md — the exact code the skill runs
PLIST_FIX_PY='
import plistlib, sys, os

plist_path = sys.argv[1]
with open(plist_path, "rb") as f:
    plist = plistlib.load(f)

short_version = plist.get("CFBundleShortVersionString", "")
bundle_version = plist.get("CFBundleVersion", "")

short_is_hardcoded = bool(short_version) and not short_version.startswith("$(")
bundle_is_hardcoded = bool(bundle_version) and not bundle_version.startswith("$(")

changed = []
if short_is_hardcoded:
    plist["CFBundleShortVersionString"] = "$(MARKETING_VERSION)"
    changed.append("CFBundleShortVersionString")
if bundle_is_hardcoded:
    plist["CFBundleVersion"] = "$(CURRENT_PROJECT_VERSION)"
    changed.append("CFBundleVersion")

if changed:
    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f)
    print("Fixed: " + ", ".join(changed))
else:
    print("no-op")
'

# Helper: create a minimal Info.plist with hardcoded version strings
make_hardcoded_plist() {
    local path="$1"
    python3 -c "
import plistlib
plist = {
    'CFBundleShortVersionString': '1.2.3',
    'CFBundleVersion': '42',
    'CFBundleIdentifier': 'com.example.app',
}
with open('$path', 'wb') as f:
    plistlib.dump(plist, f)
"
}

# Helper: create a minimal Info.plist already using variable references
make_variable_plist() {
    local path="$1"
    python3 -c "
import plistlib
plist = {
    'CFBundleShortVersionString': '\$(MARKETING_VERSION)',
    'CFBundleVersion': '\$(CURRENT_PROJECT_VERSION)',
    'CFBundleIdentifier': 'com.example.app',
}
with open('$path', 'wb') as f:
    plistlib.dump(plist, f)
"
}

echo ""
echo "aidev toolkit version-bump Xcode Info.plist Tests"
echo "=================================================="

# ─── Test 1: Xcode detection gate ──────────────────────────────────────────

echo ""
echo "Test: Xcode detection gate..."

PROJ_DIR="$TEST_HOME/non-xcode-project"
mkdir -p "$PROJ_DIR"

# With no .xcodeproj present, find returns nothing
result=$(find "$PROJ_DIR" -maxdepth 1 -name "*.xcodeproj" | head -1)
if [ -z "$result" ]; then
    pass "non-Xcode project: no .xcodeproj detected → Info.plist check skipped"
else
    fail "non-Xcode project: .xcodeproj falsely detected"
fi

# With .xcodeproj present, detection fires
XCODE_DIR="$TEST_HOME/xcode-project"
mkdir -p "$XCODE_DIR/MyApp.xcodeproj"
result=$(find "$XCODE_DIR" -maxdepth 1 -name "*.xcodeproj" | head -1)
if [ -n "$result" ]; then
    pass "Xcode project: .xcodeproj detected correctly"
else
    fail "Xcode project: .xcodeproj not detected"
fi

# ─── Test 2: Hardcoded values are replaced ─────────────────────────────────

echo ""
echo "Test: hardcoded values replaced with variable references..."

PLIST_PATH="$TEST_HOME/hardcoded/Info.plist"
mkdir -p "$(dirname "$PLIST_PATH")"
make_hardcoded_plist "$PLIST_PATH"

result=$(python3 -c "$PLIST_FIX_PY" "$PLIST_PATH")

if echo "$result" | grep -q "CFBundleShortVersionString"; then
    pass "hardcoded CFBundleShortVersionString detected and fixed"
else
    fail "hardcoded CFBundleShortVersionString not fixed: $result"
fi

if echo "$result" | grep -q "CFBundleVersion"; then
    pass "hardcoded CFBundleVersion detected and fixed"
else
    fail "hardcoded CFBundleVersion not fixed: $result"
fi

# Verify the plist now contains variable references
short=$(python3 -c "import plistlib; p=plistlib.load(open('$PLIST_PATH','rb')); print(p.get('CFBundleShortVersionString',''))")
bundle=$(python3 -c "import plistlib; p=plistlib.load(open('$PLIST_PATH','rb')); print(p.get('CFBundleVersion',''))")

if [ "$short" = "\$(MARKETING_VERSION)" ]; then
    pass "CFBundleShortVersionString → \$(MARKETING_VERSION) written correctly"
else
    fail "CFBundleShortVersionString value is '$short', expected \$(MARKETING_VERSION)"
fi

if [ "$bundle" = "\$(CURRENT_PROJECT_VERSION)" ]; then
    pass "CFBundleVersion → \$(CURRENT_PROJECT_VERSION) written correctly"
else
    fail "CFBundleVersion value is '$bundle', expected \$(CURRENT_PROJECT_VERSION)"
fi

# ─── Test 3: Variable references are a no-op ──────────────────────────────

echo ""
echo "Test: already-variable plist is a no-op..."

NOOP_PLIST="$TEST_HOME/variable/Info.plist"
mkdir -p "$(dirname "$NOOP_PLIST")"
make_variable_plist "$NOOP_PLIST"

# Record mtime before
mtime_before=$(stat -f "%m" "$NOOP_PLIST" 2>/dev/null || stat -c "%Y" "$NOOP_PLIST")
result=$(python3 -c "$PLIST_FIX_PY" "$NOOP_PLIST")

if echo "$result" | grep -q "no-op"; then
    pass "variable plist produces no-op"
else
    fail "variable plist not identified as no-op: $result"
fi

short=$(python3 -c "import plistlib; p=plistlib.load(open('$NOOP_PLIST','rb')); print(p.get('CFBundleShortVersionString',''))")
bundle=$(python3 -c "import plistlib; p=plistlib.load(open('$NOOP_PLIST','rb')); print(p.get('CFBundleVersion',''))")

if [ "$short" = "\$(MARKETING_VERSION)" ] && [ "$bundle" = "\$(CURRENT_PROJECT_VERSION)" ]; then
    pass "variable references preserved unchanged after no-op run"
else
    fail "variable references mutated: short='$short' bundle='$bundle'"
fi

# ─── Test 4: Multiple Info.plist files — all hardcoded ones fixed ──────────

echo ""
echo "Test: multiple Info.plist files — each fixed independently..."

MULTI_DIR="$TEST_HOME/multi"
mkdir -p "$MULTI_DIR/TargetA" "$MULTI_DIR/TargetB"
make_hardcoded_plist "$MULTI_DIR/TargetA/Info.plist"
make_variable_plist  "$MULTI_DIR/TargetB/Info.plist"

for plist in "$MULTI_DIR"/*/Info.plist; do
    python3 -c "$PLIST_FIX_PY" "$plist" > /dev/null
done

shortA=$(python3 -c "import plistlib; p=plistlib.load(open('$MULTI_DIR/TargetA/Info.plist','rb')); print(p.get('CFBundleShortVersionString',''))")
shortB=$(python3 -c "import plistlib; p=plistlib.load(open('$MULTI_DIR/TargetB/Info.plist','rb')); print(p.get('CFBundleShortVersionString',''))")

if [ "$shortA" = "\$(MARKETING_VERSION)" ]; then
    pass "TargetA hardcoded plist fixed in multi-target pass"
else
    fail "TargetA not fixed: $shortA"
fi

if [ "$shortB" = "\$(MARKETING_VERSION)" ]; then
    pass "TargetB variable plist unchanged in multi-target pass"
else
    fail "TargetB mutated: $shortB"
fi

# ─── Blocked: live Xcode build ─────────────────────────────────────────────

echo ""
skip_blocked "Build Xcode project after fix — confirm version resolves" \
    "requires Xcode.app, xcodebuild, and a real Swift project"

echo ""
echo "=================================================="
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-version-bump-xcode PASSED"
    exit 0
else
    echo "✗ test-version-bump-xcode FAILED"
    exit 1
fi
