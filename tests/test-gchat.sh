#!/usr/bin/env bash
# gchat module: wrapper arg handling, notifier validation, backbone-notify integration, installer wiring,
# and no project-specific wording. No network, no mocks — the live Chat API calls need a real OAuth token
# and are not exercised here (blocked without credentials).
# Run from the aidev-toolkit root: bash tests/test-gchat.sh
set -uo pipefail
exec </dev/null

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/modules/gchat"
BB="$ROOT/modules/backbone/scripts"
TMP_DIR="$(mktemp -d)"
PASS=0; FAIL=0
trap 'rm -rf "$TMP_DIR"' EXIT
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "gchat Module Tests"
echo "=================="

# --- wrapper ---
bash "$MOD/scripts/gchat.sh" bogus >/dev/null 2>&1; rc=$?
[[ $rc -eq 4 ]] && pass "gchat.sh rejects an unknown subcommand (exit 4)" || fail "gchat.sh bogus exit $rc"

bash "$MOD/scripts/gchat.sh" send --space "Team Room" --text hi >/dev/null 2>&1; rc=$?
[[ $rc -ne 0 ]] && pass "send refuses a display name as --space" || fail "send accepted a display name"

GCHAT_CONFIG_DIR="$TMP_DIR/none" bash "$MOD/scripts/gchat.sh" auth >/dev/null 2>"$TMP_DIR/auth.err"; rc=$?
if [[ $rc -eq 2 ]] && grep -q "credentials.json" "$TMP_DIR/auth.err"; then pass "auth without credentials reports BLOCKED (exit 2)"
elif [[ $rc -ne 0 ]] && ! command -v uv >/dev/null; then echo "  SKIP  auth check (no uv, deps may be missing)"
else fail "auth without credentials: exit $rc"; fi

# --- confirm setting ---
CD="$TMP_DIR/cfg"
[[ "$(GCHAT_CONFIG_DIR=$CD bash "$MOD/scripts/gchat.sh" confirm)" == "ask" ]] && pass "confirm defaults to ask" || fail "confirm default"
GCHAT_CONFIG_DIR=$CD bash "$MOD/scripts/gchat.sh" confirm auto >/dev/null
[[ "$(GCHAT_CONFIG_DIR=$CD bash "$MOD/scripts/gchat.sh" confirm)" == "auto" ]] && pass "confirm auto persists" || fail "confirm auto"
GCHAT_CONFIG_DIR=$CD bash "$MOD/scripts/gchat.sh" confirm maybe >/dev/null 2>&1; rc=$?
[[ $rc -eq 4 ]] && pass "confirm rejects an invalid value" || fail "confirm maybe exit $rc"
echo "confirm=bogus" > "$CD/config"
GCHAT_CONFIG_DIR=$CD bash "$MOD/scripts/gchat.sh" confirm >/dev/null 2>&1; rc=$?
[[ $rc -eq 4 ]] && pass "invalid stored confirm is an error, not a silent default" || fail "bogus stored exit $rc"

# --- notifier validation ---
env -u BACKBONE_NOTIFY_TARGET BACKBONE_NOTIFY_TEXT=hi bash "$MOD/scripts/gchat-notify.sh" >/dev/null 2>&1; rc=$?
[[ $rc -eq 4 ]] && pass "notifier rejects a missing target (exit 4)" || fail "missing target exit $rc"

BACKBONE_NOTIFY_TARGET='spaces/AAA; rm -rf /' BACKBONE_NOTIFY_TEXT=hi bash "$MOD/scripts/gchat-notify.sh" >/dev/null 2>&1; rc=$?
[[ $rc -eq 4 ]] && pass "notifier rejects a target with shell metacharacters (exit 4)" || fail "metachar target exit $rc"

BACKBONE_NOTIFY_TARGET=spaces/AAA BACKBONE_NOTIFY_TEXT="" bash "$MOD/scripts/gchat-notify.sh" >/dev/null 2>&1; rc=$?
[[ $rc -eq 4 ]] && pass "notifier rejects empty text (exit 4)" || fail "empty text exit $rc"

# --- backbone-notify runs gchat-notify as notify_command (validation failure => exit 1 from backbone) ---
BBDIR="$TMP_DIR/bb"; mkdir -p "$BBDIR"
echo "notify_command=$MOD/scripts/gchat-notify.sh" > "$BBDIR/backbone.config"
bash "$BB/backbone-notify.sh" --dir "$BBDIR" --target "not-a-space" --from a --title t --id note-1 >/dev/null 2>&1; rc=$?
[[ $rc -eq 1 ]] && pass "backbone-notify reports failure when gchat-notify rejects the target" || fail "backbone-notify exit $rc"
grep -q "failed" "$BBDIR/.claude/data/backbone/pings.log" 2>/dev/null && pass "failed ping is logged" || fail "no failed entry in pings.log"

# --- hygiene / install ---
if grep -rniE "radeas|sean cummings|gmail-skill|amplifier" "$MOD" >/dev/null; then fail "project-specific wording remains in modules/gchat"; else pass "no project-specific wording in modules/gchat"; fi
grep -q '"gchat.md"' "$ROOT/scripts/install.sh" && pass "install.sh lists gchat.md" || fail "install.sh missing gchat.md"
[[ -f "$MOD/skills/gchat.md" ]] && pass "skill file exists" || fail "skill file missing"

echo ""
echo "Tests run: $((PASS + FAIL))"
echo "Tests passed: $PASS"
echo "Tests failed: $FAIL"
[[ $FAIL -eq 0 ]]
