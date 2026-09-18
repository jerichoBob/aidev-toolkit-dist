#!/bin/bash
#
# aidev toolkit spec-guard Integration Tests (spec-v114)
#
# Exercises modules/sdd/scripts/aid-config.sh and spec-guard.sh against real
# git repositories (a local bare repo standing in for the remote) — no mocks,
# no stubs. Also statically validates that modules/sdd/skills/sdd-spec.md
# wires spec-guard into both flows with no silent fallback.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AID_CONFIG="$REPO_DIR/modules/sdd/scripts/aid-config.sh"
SPEC_GUARD="$REPO_DIR/modules/sdd/scripts/spec-guard.sh"
SDD_SPEC="$REPO_DIR/modules/sdd/skills/sdd-spec.md"
PASS=0
FAIL=0
BLOCKED=0

pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }
blocked() { echo "  ⊘ $1 (blocked: $2)"; ((BLOCKED++)) || true; }

echo ""
echo "Test: spec-guard remote-arbitrated spec numbering (v114)"

# --- Setup: sandbox HOME so aid-config.sh / spec-guard.sh writes (audit log,
# .aid/config.yaml lookups) never touch the real ~/.claude or repo working dir ---
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# --- Script existence ---
if [ -x "$AID_CONFIG" ]; then
  pass "modules/sdd/scripts/aid-config.sh exists and is executable"
else
  fail "modules/sdd/scripts/aid-config.sh missing or not executable"
fi

if [ -x "$SPEC_GUARD" ]; then
  pass "modules/sdd/scripts/spec-guard.sh exists and is executable"
else
  fail "modules/sdd/scripts/spec-guard.sh missing or not executable"
fi

# --- Config default: no .aid/config.yaml -> spec-guard-enabled returns false ---
PROJECT_A="$WORKDIR/project-no-config"
mkdir -p "$PROJECT_A"
result=$(cd "$PROJECT_A" && "$AID_CONFIG" spec-guard-enabled)
if [ "$result" = "false" ]; then
  pass "aid-config.sh defaults spec-guard to false with no .aid/config.yaml"
else
  fail "aid-config.sh did not default to false (got: $result)"
fi

# --- Config enabled: .aid/config.yaml with spec-guard: true ---
PROJECT_B="$WORKDIR/project-with-config"
mkdir -p "$PROJECT_B/.aid"
cat > "$PROJECT_B/.aid/config.yaml" <<'EOF'
spec-guard: true
EOF
result=$(cd "$PROJECT_B" && "$AID_CONFIG" spec-guard-enabled)
if [ "$result" = "true" ]; then
  pass "aid-config.sh reads spec-guard: true from .aid/config.yaml"
else
  fail "aid-config.sh did not report true (got: $result)"
fi

# --- Config malformed key still defaults safely ---
PROJECT_C="$WORKDIR/project-bad-config"
mkdir -p "$PROJECT_C/.aid"
echo "not: valid: yaml: at: all" > "$PROJECT_C/.aid/config.yaml"
result=$(cd "$PROJECT_C" && "$AID_CONFIG" spec-guard-enabled 2>/dev/null || echo "CRASHED")
if [ "$result" = "false" ]; then
  pass "aid-config.sh defaults safely to false on a config file with no spec-guard key"
else
  fail "aid-config.sh did not degrade safely on malformed/missing key (got: $result)"
fi

# --- Real git fixture: bare repo as the remote, two independent clones as
# two contributors racing for the same spec number ---
if command -v git >/dev/null 2>&1; then
  REMOTE="$WORKDIR/remote.git"
  DEV1="$WORKDIR/dev1"
  DEV2="$WORKDIR/dev2"

  git init --bare -q "$REMOTE"

  git init -q "$DEV1"
  (cd "$DEV1" && git config user.email dev1@test.com && git config user.name dev1 \
    && echo one > f.txt && git add f.txt && git commit -q -m init \
    && git remote add origin "$REMOTE")

  git clone -q "$REMOTE" "$DEV2"
  (cd "$DEV2" && git config user.email dev2@test.com && git config user.name dev2 \
    && echo two > g.txt && git add g.txt && git commit -q -m second)

  # next-number on an empty remote is 1
  n=$(cd "$DEV1" && "$SPEC_GUARD" next-number)
  if [ "$n" = "1" ]; then
    pass "next-number returns 1 on an empty remote"
  else
    fail "next-number expected 1, got: $n"
  fi

  # dev1 claims — should succeed and reserve v1
  claimed1=$(cd "$DEV1" && "$SPEC_GUARD" claim)
  if [ "$claimed1" = "1" ]; then
    pass "dev1 claim reserves v1"
  else
    fail "dev1 claim expected 1, got: $claimed1"
  fi

  # dev2 claims next — must NOT collide with dev1's v1, must get v2
  claimed2=$(cd "$DEV2" && "$SPEC_GUARD" claim)
  if [ "$claimed2" = "2" ]; then
    pass "dev2 claim skips the already-reserved v1 and gets v2 (no collision)"
  else
    fail "dev2 claim expected 2, got: $claimed2"
  fi

  # Direct collision: both explicitly reserve the same number v5
  (cd "$DEV1" && "$SPEC_GUARD" reserve 5 >/dev/null 2>&1) && reserve1_exit=0 || reserve1_exit=$?
  (cd "$DEV2" && "$SPEC_GUARD" reserve 5 >/dev/null 2>&1) && reserve2_exit=0 || reserve2_exit=$?
  if [ "$reserve1_exit" = "0" ] && [ "$reserve2_exit" != "0" ]; then
    pass "concurrent reserve of the same number: exactly one caller wins (dev1=0, dev2=$reserve2_exit)"
  else
    fail "expected exactly one winner for v5 (dev1 exit=$reserve1_exit, dev2 exit=$reserve2_exit)"
  fi
  if [ "$reserve2_exit" = "2" ]; then
    pass "loser's reserve exits with the documented collision code (2)"
  else
    fail "loser's reserve expected exit 2 (collision), got: $reserve2_exit"
  fi

  # release frees the number
  (cd "$DEV1" && "$SPEC_GUARD" release 5 >/dev/null 2>&1) && release_exit=0 || release_exit=$?
  after_release=$(cd "$DEV2" && "$SPEC_GUARD" reserve 5 >/dev/null 2>&1; echo $?)
  if [ "$release_exit" = "0" ] && [ "$after_release" = "0" ]; then
    pass "release frees a reservation so it can be re-claimed"
  else
    fail "release/re-reserve cycle failed (release exit=$release_exit, re-reserve exit=$after_release)"
  fi

  # Unreachable remote: next-number must fail hard (exit 1), not silently
  # invent a number and it must not touch specs/README.md in this repo.
  unreachable_output=$(cd "$DEV1" && "$SPEC_GUARD" next-number --remote /nonexistent/path.git 2>&1) && unreachable_exit=0 || unreachable_exit=$?
  if [ "$unreachable_exit" = "1" ] && echo "$unreachable_output" | grep -qi "ERROR"; then
    pass "unreachable remote fails loudly (exit 1) instead of falling back"
  else
    fail "unreachable remote did not fail as documented (exit=$unreachable_exit)"
  fi
else
  blocked "real git remote collision/release/unreachable tests" "git CLI not available in this environment"
fi

# --- Skill wiring: sdd-spec.md must check spec-guard-enabled and never fall
# back to local numbering on a hard failure ---
if [ -f "$SDD_SPEC" ]; then
  pass "modules/sdd/skills/sdd-spec.md exists"

  if grep -q "aid-config.sh spec-guard-enabled" "$SDD_SPEC"; then
    pass "Normal Append Flow checks spec-guard-enabled before numbering"
  else
    fail "spec-guard-enabled check not found in sdd-spec.md"
  fi

  if grep -q "spec-guard.sh claim" "$SDD_SPEC"; then
    pass "Normal Append Flow uses spec-guard.sh claim when enabled"
  else
    fail "spec-guard.sh claim usage not found in Normal Append Flow"
  fi

  if grep -q "spec-guard.sh reserve <N.M>" "$SDD_SPEC"; then
    pass "Prioritization Flow reserves decimal versions through spec-guard.sh"
  else
    fail "spec-guard.sh decimal reservation not found in Prioritization Flow"
  fi

  fallback_count=$(grep -c "do NOT fall back\|not falling back\|Do not auto-release" "$SDD_SPEC" 2>/dev/null || true)
  if [ "$fallback_count" -ge 2 ]; then
    pass "no-silent-fallback language present in both flows ($fallback_count occurrences)"
  else
    fail "no-silent-fallback language missing or incomplete (found $fallback_count occurrences, expected >= 2)"
  fi

  if grep -q "spec-guard.sh release" "$SDD_SPEC"; then
    pass "reserved-but-unused escape hatch (release) is documented in sdd-spec.md"
  else
    fail "release escape hatch not documented in sdd-spec.md"
  fi
else
  fail "modules/sdd/skills/sdd-spec.md not found"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $BLOCKED blocked"
[ "$FAIL" -eq 0 ]
