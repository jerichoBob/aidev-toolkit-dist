#!/bin/bash
#
# aidev toolkit Cross-Platform Test Suite
#
# Tests OS detection logic in install.sh and platform guard behavior in
# macOS-only scripts. Simulates non-Darwin uname to verify guards fire correctly.
#
# WSL2-dependent tests (live install on Windows) are marked BLOCKED.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_DIR/scripts/install.sh"
SCREENSHOTS_SCRIPT="$REPO_DIR/scripts/screenshots.sh"
PASS=0
FAIL=0
BLOCKED=0

pass()    { echo "  ✓ $1"; ((PASS++)) || true; }
fail()    { echo "  ✗ $1"; ((FAIL++)) || true; }
blocked() { echo "  ⊘ $1 [BLOCKED: $2]"; ((BLOCKED++)) || true; }

check() {
    if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi
}

echo ""
echo "Cross-Platform Tests"
echo "===================="

# ── OS Detection in install.sh ───────────────────────────────────────────────

echo ""
echo "OS Detection (install.sh):"

check "grep -q 'OS_TYPE=\"\$(uname -s' '$INSTALL_SCRIPT'" \
    "install.sh uses uname -s for OS detection"

check "grep -q 'OS_PLATFORM=\"macos\"' '$INSTALL_SCRIPT'" \
    "install.sh maps Darwin to macos"

check "grep -q 'OS_PLATFORM=\"linux\"' '$INSTALL_SCRIPT'" \
    "install.sh maps Linux to linux"

check "grep -q 'OS_PLATFORM=\"gitbash\"' '$INSTALL_SCRIPT'" \
    "install.sh maps MINGW/MSYS to gitbash"

# ── Per-Platform Install Hints ───────────────────────────────────────────────

echo ""
echo "Cross-Platform Install Hints (install.sh):"

check "grep -q 'apt-get' '$INSTALL_SCRIPT'" \
    "install.sh includes apt-get install hint for Linux"

check "grep -q 'winget' '$INSTALL_SCRIPT'" \
    "install.sh includes winget install hint for Git Bash"

check "grep -q 'brew install gh' '$INSTALL_SCRIPT'" \
    "install.sh includes brew install hint for macOS"

check "grep -q 'brew install jq' '$INSTALL_SCRIPT'" \
    "install.sh includes jq install hint for macOS"

check "grep -q 'MINGW\|Git Bash detected' '$INSTALL_SCRIPT'" \
    "install.sh warns Git Bash users about symlink requirements"

# ── .gitattributes CRLF Guard ────────────────────────────────────────────────

echo ""
echo ".gitattributes CRLF Guard:"

check "[ -f '$REPO_DIR/.gitattributes' ]" \
    ".gitattributes exists"

check "grep -q '*.sh.*eol=lf' '$REPO_DIR/.gitattributes'" \
    ".gitattributes enforces LF for .sh files"

check "grep -q '*.md.*eol=lf' '$REPO_DIR/.gitattributes'" \
    ".gitattributes enforces LF for .md files"

# ── screenshots.sh macOS Guard ───────────────────────────────────────────────

echo ""
echo "screenshots.sh Platform Guard:"

check "grep -q 'Darwin' '$SCREENSHOTS_SCRIPT'" \
    "screenshots.sh has Darwin OS guard"

# Simulate non-Darwin environment: create a fake 'uname' binary in a temp dir
FAKE_UNAME_DIR=$(mktemp -d)
cat > "$FAKE_UNAME_DIR/uname" << 'EOF'
#!/bin/bash
echo "Linux"
EOF
chmod +x "$FAKE_UNAME_DIR/uname"

GUARD_OUTPUT=$(PATH="$FAKE_UNAME_DIR:$PATH" bash "$SCREENSHOTS_SCRIPT" 2>&1) || true
if echo "$GUARD_OUTPUT" | grep -qi "macOS only\|not supported"; then
    pass "screenshots.sh prints macOS-only message on non-Darwin"
else
    fail "screenshots.sh does not print macOS-only message on non-Darwin (got: $GUARD_OUTPUT)"
fi

# Guard should exit 0 so it doesn't break surrounding workflows
GUARD_RC=0
PATH="$FAKE_UNAME_DIR:$PATH" bash "$SCREENSHOTS_SCRIPT" >/dev/null 2>&1 || GUARD_RC=$?
if [[ "$GUARD_RC" == "0" ]]; then
    pass "screenshots.sh exits 0 on non-Darwin (does not break workflows)"
else
    fail "screenshots.sh exits $GUARD_RC on non-Darwin (expected 0)"
fi

rm -rf "$FAKE_UNAME_DIR"

# ── Skill macOS Guards (markdown) ────────────────────────────────────────────

echo ""
echo "Skill File macOS Guards:"

check "grep -q 'macOS only' '$REPO_DIR/skills/browser-harness.md'" \
    "browser-harness.md documents macOS-only restriction"

check "grep -q 'macOS only' '$REPO_DIR/skills/gmail-digest.md'" \
    "gmail-digest.md documents macOS-only restriction"

check "grep -q 'macOS only\|macOS' '$REPO_DIR/skills/screenshots.md'" \
    "screenshots.md documents macOS-only scope"

# ── README Windows Docs ──────────────────────────────────────────────────────

echo ""
echo "README Windows Documentation:"

check "grep -qi 'WSL2' '$REPO_DIR/README.md'" \
    "README.md documents WSL2 installation"

check "grep -qi 'Git Bash' '$REPO_DIR/README.md'" \
    "README.md documents Git Bash installation"

check "grep -qi 'macOS.only skills\|macOS-only skills' '$REPO_DIR/README.md'" \
    "README.md lists macOS-only skills"

# ── WSL2 Live Tests (BLOCKED) ────────────────────────────────────────────────

echo ""
echo "WSL2 Live Tests (BLOCKED — require live WSL2 environment):"

blocked "fresh install in WSL2 Ubuntu" \
    "no WSL2 environment available in CI — test manually: run install.sh in WSL2 and verify all skills symlink"

blocked "tests/run-all.sh passes on WSL2" \
    "no WSL2 environment available in CI — test manually: run tests/run-all.sh in WSL2"

blocked "idempotent re-install on WSL2" \
    "no WSL2 environment available in CI — test manually: run install.sh twice and verify no errors"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "========================"
echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
