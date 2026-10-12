#!/usr/bin/env bash
# Tests scripts/statusline.sh: ctx colored bar + aid update-available glow.
# Runs the real script against a throwaway HOME with real files (no mocks).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/statusline.sh"
pass=0; fail=0

check() { # name, condition-exit-code
  if [[ "$2" == "0" ]]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi
}

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.claude/aidev-toolkit"
cat > "$TMP_HOME/.claude/statusline-config.json" <<'EOF'
{"enabled": true, "components": {"dir": false, "branch": false, "ctx": true, "model": false, "effort": false, "vim": false, "aid_version": true}}
EOF
echo "0.101.0" > "$TMP_HOME/.claude/aidev-toolkit/VERSION"

run() { echo "{\"context_window\":{\"used_percentage\":$1},\"cwd\":\"/tmp\"}" | HOME="$TMP_HOME" bash "$SCRIPT"; }
strip() { sed $'s/\033\\[[0-9;]*m//g'; }

# --- ctx bar ---
out=$(run 4 | strip)
[[ "$out" == *"ctx ▰▱▱▱▱▱▱▱▱▱ 4%"* ]]; check "4% lights 1 of 10 cells" $?
out=$(run 0 | strip)
[[ "$out" == *"ctx ▱▱▱▱▱▱▱▱▱▱ 0%"* ]]; check "0% lights no cells" $?
out=$(run 50 | strip)
[[ "$out" == *"ctx ▰▰▰▰▰▱▱▱▱▱ 50%"* ]]; check "50% lights 5 cells" $?
out=$(run 100 | strip)
[[ "$out" == *"ctx ▰▰▰▰▰▰▰▰▰▰ 100%"* ]]; check "100% lights 10 cells" $?
out=$(run 250 | strip)
[[ "$out" == *"100%"* ]]; check "over-range clamps to 100%" $?
run 100 | grep -q $'\033\\[38;5;196m'; check "last cell is red (196)" $?
run 100 | grep -q $'\033\\[38;5;46m'; check "first cell is green (46)" $?

# percentage color matches the last lit cell's hue (14% -> 2 cells -> 82; 100% -> 196)
run 14 | grep -q $'\033\\[38;5;82m14%'; check "14% number matches 2nd cell hue (82)" $?
run 100 | grep -q $'\033\\[38;5;196m100%'; check "100% number matches last cell hue (196)" $?
run 0 | grep -q $'\033\\[38;5;46m0%'; check "0% number is green (46)" $?

# --- no cache file and no git clone: silent, no marker ---
err=$(run 4 2>&1 >/dev/null)
[[ -z "$err" ]]; check "missing cache produces no stderr" $?
rm -f "$TMP_HOME/.claude/.aid-latest-version"

# --- aid update glow (cache fresh so no background fetch is attempted) ---
CACHE="$TMP_HOME/.claude/.aid-latest-version"
echo "0.102.1" > "$CACHE"
out=$(run 4 | strip)
[[ "$out" == *"aid:0.101.0 ⬆0.102.1"* ]]; check "newer upstream shows marker" $?
run 4 | grep -Eq $'\033\\[(1;)?38;5;(220|136)maid'; check "newer upstream pulses gold" $?

echo "0.101.0" > "$CACHE"
out=$(run 4 | strip)
[[ "$out" == *"aid:0.101.0"* && "$out" != *"⬆"* ]]; check "same version: no marker" $?

echo "0.100.0" > "$CACHE"
out=$(run 4 | strip)
[[ "$out" != *"⬆"* ]]; check "older upstream: no marker" $?

echo "0.99.0" > "$TMP_HOME/.claude/aidev-toolkit/VERSION"
echo "0.100.0" > "$CACHE"
out=$(run 4 | strip)
[[ "$out" == *"⬆0.100.0"* ]]; check "version compare is numeric (0.99.0 < 0.100.0)" $?

echo; echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
