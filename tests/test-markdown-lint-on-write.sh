#!/bin/bash
#
# Tests for v87: Markdown Lint on Write
#
# Verifies that the PostToolUse hook in ~/.claude/settings.json is wired
# to run markdownlint on .md file writes, with node_modules exclusion and
# platform check.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

check() {
    if eval "$1"; then
        pass "$2"
    else
        fail "$2"
    fi
}

echo "aidev toolkit test-markdown-lint-on-write.sh Tests"
echo "==================================================="

echo ""
echo "Section: Hook definition in install.sh"
echo "---------------------------------------"

check "grep -q 'markdownlint' '$REPO_DIR/scripts/install.sh'" \
    "install.sh contains markdownlint hook command"

check "grep -q 'node_modules' '$REPO_DIR/scripts/install.sh'" \
    "install.sh hook excludes node_modules"

check "grep -q 'command -v markdownlint' '$REPO_DIR/scripts/install.sh'" \
    "install.sh hook has platform check for missing markdownlint"

check "grep -q 'PostToolUse' '$REPO_DIR/scripts/install.sh'" \
    "install.sh wires PostToolUse hook"

echo ""
echo "Section: Hook present in installed ~/.claude/settings.json"
echo "-----------------------------------------------------------"

SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo "  ⊘ BLOCKED: $SETTINGS not found — run /aid-update to install"
else
    check "python3 -c \"
import json
with open('$SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {}).get('PostToolUse', [])
found = any('markdownlint' in str(h) for e in hooks for h in e.get('hooks', []))
assert found, 'markdownlint hook not found'
\"" "markdownlint PostToolUse hook registered in settings.json"

    check "python3 -c \"
import json
with open('$SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {}).get('PostToolUse', [])
for e in hooks:
    for h in e.get('hooks', []):
        if 'markdownlint' in h.get('command', ''):
            assert 'node_modules' in h['command'], 'node_modules exclusion missing'
\"" "node_modules exclusion present in installed hook"

    check "python3 -c \"
import json
with open('$SETTINGS') as f:
    d = json.load(f)
hooks = d.get('hooks', {}).get('PostToolUse', [])
for e in hooks:
    for h in e.get('hooks', []):
        if 'markdownlint' in h.get('command', ''):
            cmd = h['command']
            assert 'command -v markdownlint' in cmd or 'which markdownlint' in cmd, 'platform check missing'
\"" "platform check present in installed hook"
fi

echo ""
echo "Section: Hook behavior — valid markdown file"
echo "---------------------------------------------"

if ! command -v markdownlint &>/dev/null; then
    echo "  ⊘ BLOCKED: markdownlint not installed — cannot test hook execution"
else
    TMPFILE=$(mktemp /tmp/test-valid-XXXXXX.md)
    printf '# Test File\n\nThis is a valid markdown file.\n\n## Section\n\nSome content.\n' > "$TMPFILE"

    CONFIG="$HOME/.claude/aidev-toolkit/templates/markdownlint.json"
    [ -f "$CONFIG" ] || CONFIG="$REPO_DIR/templates/markdownlint.json"

    if markdownlint --fix --config "$CONFIG" "$TMPFILE" 2>&1; then
        pass "markdownlint exits 0 on valid .md file"
    else
        fail "markdownlint should exit 0 on valid .md file"
    fi
    rm -f "$TMPFILE"
fi

echo ""
echo "Section: Hook behavior — bad markdown file (MD040 violation)"
echo "-------------------------------------------------------------"

if ! command -v markdownlint &>/dev/null; then
    echo "  ⊘ BLOCKED: markdownlint not installed — cannot test hook execution"
else
    TMPFILE=$(mktemp /tmp/test-bad-XXXXXX.md)
    printf '# Test\n\n```\nsome code\n```\n' > "$TMPFILE"

    CONFIG="$HOME/.claude/aidev-toolkit/templates/markdownlint.json"
    [ -f "$CONFIG" ] || CONFIG="$REPO_DIR/templates/markdownlint.json"

    if ! markdownlint --config "$CONFIG" "$TMPFILE" 2>&1 | grep -q "MD040"; then
        fail "markdownlint should report MD040 on unlabeled fenced block"
    else
        pass "markdownlint reports MD040 error on bad .md file"
    fi
    rm -f "$TMPFILE"
fi

echo ""
echo "=================================================="
echo "Results: $PASS passed, $FAIL failed, 0 blocked (skipped)"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "✗ test-markdown-lint-on-write FAILED"
    exit 1
else
    echo "✓ test-markdown-lint-on-write PASSED"
    exit 0
fi
