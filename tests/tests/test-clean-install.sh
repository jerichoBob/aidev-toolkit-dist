#!/bin/bash
#
# aidev toolkit clean-install.sh Partial Test Suite
#
# Tests the symlink-removal loop logic in isolation — verifies that only
# aidev-toolkit symlinks are removed and other ~/.claude files are untouched.
# The GitHub clone/install step requires live network + auth and is marked blocked.
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

# Replicate the symlink-removal logic from clean-install.sh
# so we can run it against a fixture directory without needing
# to invoke the full script (which requires gh CLI and network).
run_symlink_removal() {
    local commands_dir="$1"
    local toolkit_dir="$2"

    if [ -d "$commands_dir" ]; then
        shopt -s nullglob
        for file in "$commands_dir"/*.md; do
            if [ -L "$file" ]; then
                target=$(readlink "$file")
                if [[ "$target" == *"aidev-toolkit/skills/"* ]] || \
                   [[ "$target" == *"aidev-toolkit/modules/"* ]] || \
                   [[ "$target" == "../aidev-toolkit/skills/"* ]]; then
                    rm "$file"
                fi
            fi
        done
        shopt -u nullglob
    fi
}

echo ""
echo "aidev toolkit clean-install.sh Partial Tests"
echo "=============================================="

# ─── Test 1: removes only toolkit symlinks, leaves other files intact ──────

echo ""
echo "Test: removes only toolkit symlinks, leaves other files intact..."

COMMANDS_DIR="$TEST_HOME/.claude/commands"
TOOLKIT_DIR="$TEST_HOME/.claude/aidev-toolkit"
mkdir -p "$COMMANDS_DIR" "$TOOLKIT_DIR/skills"

# Create two fake toolkit skill files
touch "$TOOLKIT_DIR/skills/commit.md"
touch "$TOOLKIT_DIR/skills/lint.md"

# Symlinks pointing to aidev-toolkit (toolkit-owned)
ln -s "$TOOLKIT_DIR/skills/commit.md" "$COMMANDS_DIR/commit.md"
ln -s "$TOOLKIT_DIR/skills/lint.md" "$COMMANDS_DIR/lint.md"

# A non-toolkit regular file (user-owned — must not be touched)
echo "# My custom skill" > "$COMMANDS_DIR/my-custom-skill.md"

# A non-toolkit symlink pointing elsewhere (must not be touched)
OTHER_DIR="$TEST_HOME/other"
mkdir -p "$OTHER_DIR"
touch "$OTHER_DIR/foreign.md"
ln -s "$OTHER_DIR/foreign.md" "$COMMANDS_DIR/foreign.md"

run_symlink_removal "$COMMANDS_DIR" "$TOOLKIT_DIR"

# Toolkit symlinks should be gone
if [ ! -e "$COMMANDS_DIR/commit.md" ]; then
    pass "toolkit symlink commit.md removed"
else
    fail "toolkit symlink commit.md still present"
fi

if [ ! -e "$COMMANDS_DIR/lint.md" ]; then
    pass "toolkit symlink lint.md removed"
else
    fail "toolkit symlink lint.md still present"
fi

# User file must still be present
if [ -f "$COMMANDS_DIR/my-custom-skill.md" ]; then
    pass "user file my-custom-skill.md preserved"
else
    fail "user file my-custom-skill.md was removed"
fi

# Non-toolkit symlink must still be present
if [ -L "$COMMANDS_DIR/foreign.md" ]; then
    pass "non-toolkit symlink foreign.md preserved"
else
    fail "non-toolkit symlink foreign.md was removed"
fi

# ─── Test 2: missing/already-removed symlinks don't cause errors ───────────

echo ""
echo "Test: missing symlinks are handled gracefully..."

COMMANDS_DIR2="$TEST_HOME/.claude/commands2"
TOOLKIT_DIR2="$TEST_HOME/.claude/aidev-toolkit2"
mkdir -p "$COMMANDS_DIR2" "$TOOLKIT_DIR2/skills"
touch "$TOOLKIT_DIR2/skills/aid.md"

# Create symlink then remove it — simulates already-removed state
ln -s "$TOOLKIT_DIR2/skills/aid.md" "$COMMANDS_DIR2/aid.md"
rm "$COMMANDS_DIR2/aid.md"

# Running removal on an empty directory should not error
set +e
run_symlink_removal "$COMMANDS_DIR2" "$TOOLKIT_DIR2"
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
    pass "removal loop handles empty/missing symlinks gracefully (exit 0)"
else
    fail "removal loop exited non-zero on empty directory: $exit_code"
fi

# ─── Test 3: non-existent commands/ directory is handled gracefully ─────────

echo ""
echo "Test: non-existent commands/ directory is handled gracefully..."

NONEXIST_DIR="$TEST_HOME/.claude/does-not-exist"
NONEXIST_TOOLKIT="$TEST_HOME/.claude/toolkit-nonexist"

set +e
run_symlink_removal "$NONEXIST_DIR" "$NONEXIST_TOOLKIT"
exit_code=$?
set -e

if [ "$exit_code" -eq 0 ]; then
    pass "removal loop handles non-existent commands/ dir gracefully"
else
    fail "removal loop exited non-zero on non-existent dir: $exit_code"
fi

# ─── Blocked: GitHub clone/install step ─────────────────────────────────────

echo ""
skip_blocked "Full clean-install.sh end-to-end" \
    "requires live GitHub network access and gh CLI authentication"

echo ""
echo "=============================================="
printf "Results: %d passed, %d failed, %d blocked (skipped)\n" $PASS $FAIL $BLOCKED
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "✓ test-clean-install PASSED"
    exit 0
else
    echo "✗ test-clean-install FAILED"
    exit 1
fi
