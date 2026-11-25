#!/bin/bash
#
# aidev toolkit install.sh configure_* Failure Propagation Tests
#
# Verifies each configure_* function in install.sh propagates the python3
# heredoc's exit code instead of unconditionally returning 0.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_DIR/scripts/install.sh"
TEST_HOME=$(mktemp -d)
PASS=0
FAIL=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

echo ""
echo "aidev toolkit install.sh configure_* Failure Tests"
echo "===================================================="

# Curated PATH containing only core system utilities (bash, cat, mkdir, sed, mv, rm,
# mktemp, dirname, chmod) plus a fake python3 that always fails. This deliberately
# excludes real jq/python3 install locations (e.g. /opt/homebrew/bin) so
# configure_permissions falls through to its python3 branch instead of its jq branch.
FAKE_BIN="$TEST_HOME/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/python3" << 'EOF'
#!/bin/bash
# Simulate a failing python3 (e.g. malformed settings.json / import error)
cat > /dev/null   # consume heredoc stdin
exit 1
EOF
chmod +x "$FAKE_BIN/python3"

# configure_permissions tries jq first; exclude /usr/bin (where jq lives on this
# machine) from PATH so `command -v jq` fails and the function falls through to
# its python3 branch, which is what this test exercises.
CURATED_PATH="$FAKE_BIN:/bin"

# Extract each configure_* function body from install.sh and test it in isolation
# with the failing python3 stub on PATH, real jq/python3 removed from PATH.
for fn in configure_permissions configure_hooks configure_telemetry_hook \
          configure_context_thermostat_hook configure_statusline; do
    echo ""
    echo "Test: $fn propagates python3 failure..."

    fn_body=$(sed -n "/^${fn}() {/,/^}/p" "$INSTALL_SCRIPT")

    if [ -z "$fn_body" ]; then
        fail "$fn: could not extract function body from install.sh"
        continue
    fi

    if PATH="$CURATED_PATH" HOME="$TEST_HOME" bash -c "
        $fn_body
        $fn
    " > /dev/null 2>&1; then
        fail "$fn: reported success despite python3 exiting non-zero"
    else
        pass "$fn: correctly propagates python3 failure (non-zero return)"
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "===================================================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
