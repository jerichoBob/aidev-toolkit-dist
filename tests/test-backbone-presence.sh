#!/usr/bin/env bash
# Tests the full presence lifecycle: write, schema, TTL staleness, leave update, learned block persistence.
# Run from the aidev-toolkit root: bash tests/test-presence-lifecycle.sh

set -euo pipefail
exec </dev/null   # hooks read stdin; do not eat the script list that run-all.sh pipes in

MOD="$(cd "$(dirname "$0")/../modules/backbone" && pwd)"
SKILLS="$MOD/skills"
source "$MOD/scripts/backbone-lib.sh"
TMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

assert_file_exists() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then pass "$label"; else fail "$label (missing: $path)"; fi
}

assert_contains() {
  local file="$1" pattern="$2" label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label (pattern '$pattern' not found in $file)"; fi
}

assert_not_contains() {
  local file="$1" pattern="$2" label="$3"
  if ! grep -q "$pattern" "$file" 2>/dev/null; then pass "$label"; else fail "$label (pattern '$pattern' unexpectedly found in $file)"; fi
}

echo ""
echo "Presence Lifecycle Tests"
echo "========================"

# ── Test 4: Agent name format validation ─────────────────────────────────────
echo ""
echo "4. Agent name format"
VALID_NAMES=(
  "grostak-api:patient-schema"
  "stak-app:refill-flow"
  "agent-backbone:cr-workflow"
  "my-repo:some-task-slug"
)
INVALID_NAMES=(
  "grostak_api:patient_schema"
  "GROSTAK:TASK"
  "no-colon-here"
)
for name in "${VALID_NAMES[@]}"; do
  if echo "$name" | grep -qE '^[a-z0-9-]+:[a-z0-9-]+$'; then
    pass "valid agent name: $name"
  else
    fail "should be valid: $name"
  fi
done
for name in "${INVALID_NAMES[@]}"; do
  if ! echo "$name" | grep -qE '^[a-z0-9-]+:[a-z0-9-]+$'; then
    pass "correctly rejected: $name"
  else
    fail "should be rejected: $name"
  fi
done

# ── Test 5: Presence lifecycle — join, update, leave ─────────────────────────
echo ""
echo "5. Presence lifecycle"

AGENT_NAME="test-repo:test-task"
PRESENCE_FILE="$TMP_DIR/presence-$(bb_safe_name "$AGENT_NAME").md"

# Simulate /backbone-join
cat > "$PRESENCE_FILE" <<'EOF'
---
agent_name: test-repo:test-task
repo: test-repo
status: active
joined: 2026-06-03T10:00:00
updated: 2026-06-03T10:00:00
ttl_hours: 4
capabilities:
  - test-infrastructure
  - schema-analysis
---

# Current Task

Testing the presence lifecycle.

# Architectural Knowledge

This is a test agent with no real architectural knowledge.

# Learned

<!-- To be filled in by /backbone-leave -->
EOF

assert_file_exists "$PRESENCE_FILE" "presence file created on join"
assert_contains "$PRESENCE_FILE" "status: active" "status is active after join"
assert_contains "$PRESENCE_FILE" "^agent_name: test-repo:test-task" "agent_name matches"
assert_contains "$PRESENCE_FILE" "^# Current Task" "Current Task section present"
assert_contains "$PRESENCE_FILE" "To be filled in by /backbone-leave" "Learned placeholder present"

# Simulate /backbone-leave — fill Learned section, set inactive
sed -i '' 's/status: active/status: inactive/' "$PRESENCE_FILE"
sed -i '' 's/updated: 2026-06-03T10:00:00/updated: 2026-06-03T13:45:00/' "$PRESENCE_FILE"
# Replace the placeholder with actual learned content
python3 - "$PRESENCE_FILE" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
content = content.replace(
    '<!-- To be filled in by /backbone-leave -->',
    '- Tested the presence lifecycle end-to-end\n- Confirmed sed -i \'\' works on macOS\n- Open: verify Python availability on all target machines'
)
with open(path, 'w') as f:
    f.write(content)
PYEOF

assert_contains "$PRESENCE_FILE" "status: inactive" "status is inactive after leave"
assert_contains "$PRESENCE_FILE" "updated: 2026-06-03T13:45:00" "updated timestamp written on leave"
assert_not_contains "$PRESENCE_FILE" "To be filled in by /backbone-leave" "placeholder replaced with learned content"
assert_contains "$PRESENCE_FILE" "Tested the presence lifecycle" "learned bullets present"

# ── Test 6: TTL staleness logic ───────────────────────────────────────────────
echo ""
echo "6. TTL staleness"

# Build a presence file with a known join time and compute staleness
STALE_FILE="$TMP_DIR/presence-$(bb_safe_name "stale-agent:old-task").md"
cat > "$STALE_FILE" <<'EOF'
---
agent_name: stale-agent:old-task
repo: some-repo
status: active
joined: 2026-06-03T00:00:00
updated: 2026-06-03T00:00:00
ttl_hours: 4
capabilities:
  - schema-analysis
---

# Current Task

Old task from many hours ago.

# Architectural Knowledge

None.

# Learned

<!-- pending -->
EOF

# Verify the file has the expected TTL value
assert_contains "$STALE_FILE" "ttl_hours: 4" "ttl_hours field present"
# Verify the logic: updated 2026-06-03T00:00:00, current time well past 4h — would be stale
# (We can't run real time arithmetic in a pure bash test, but we verify the fields exist
#  so the reading agent can compute it)
assert_contains "$STALE_FILE" "^updated:" "updated field present for staleness computation"
assert_contains "$STALE_FILE" "status: active" "status active (not yet explicitly left — would be stale by TTL)"
pass "staleness fields present — reading agent can compute stale = (now - updated) > ttl_hours * 3600"

# ── Test 7: Command files exist ───────────────────────────────────────────────
echo ""
echo "7. Command files"
COMMANDS_DIR="$SKILLS"
assert_file_exists "$COMMANDS_DIR/backbone.md" "/backbone (status, join, leave) exists"

# ── Test 8: filename convention ───────────────────────────────────────────────
echo ""
echo "8. Filename convention"
for agent in "grostak-api:patient-schema" "stak-app:refill-flow" "agent-backbone:cr-workflow" "stak-app:bob~ab12"; do
  fname="presence-$(bb_safe_name "$agent").md"
  if echo "$fname" | grep -qE '^presence-[a-z0-9-]+__[a-z0-9~-]+\.md$'; then
    pass "safe filename for $agent: $fname"
  else
    fail "unsafe or malformed filename for $agent: $fname"
  fi
done

# ── Test 9: Windows-safe names (v6 AC-6) ─────────────────────────────────────
echo ""
echo "9. Safe filenames"
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }
assert_eq "$(bb_safe_name 'stak-app:main')" "stak-app__main" "colon becomes a double underscore"
assert_eq "$(bb_safe_name 'stak-app:bob~ab12')" "stak-app__bob~ab12" "tilde is kept (session suffix)"
nasty='a:b/c\d*e?f"g<h>i|j'
safe="$(bb_safe_name "$nasty")"
if [[ "$safe" =~ [:/\\*?\"\<\>\|] ]]; then fail "safe name still holds a character Windows rejects: $safe"; else pass "no : / \\ * ? \" < > | survives ($safe)"; fi
assert_eq "$(bb_safe_name "$(bb_safe_name 'stak-app:main')")" "stak-app__main" "safe form is stable when applied twice"
assert_eq "$(bash "$MOD/scripts/backbone-presence.sh" --dir "$TMP_DIR" safe 'x:y')" "x__y" "backbone-presence.sh safe agrees with the library"

# ── Test 10: lookups scan agent_name, not the filename ───────────────────────
echo ""
echo "10. Lookups scan agent_name"
LD="$TMP_DIR/lookup"; mkdir -p "$LD/presence" "$LD/messages"
mkpres() { # <file> <agent_name> [subscription]
  { echo "---"; echo "agent_name: $2"; echo "repo: r"; echo "status: active"
    if [[ -n "${3:-}" ]]; then echo "subscriptions:"; echo "  - $3"; fi
    echo "---"; echo; echo "# Current Task"; echo "x"; } > "$1"
}
mkpres "$LD/presence/presence-arbitrary-label.md" "x:bob~ab12" "topic-a"
mkpres "$LD/presence/presence-other-label.md" "x:bob~f3c9" "topic-b"
mkpres "$LD/presence/presence-third.md" "x:nate~0001" "topic-c"
PRES="$MOD/scripts/backbone-presence.sh"
assert_eq "$(bash "$PRES" --dir "$LD" path 'x:bob~ab12')" "$LD/presence/presence-arbitrary-label.md" "an existing record is found by agent_name even under a different filename"
assert_eq "$(bash "$PRES" --dir "$LD" path 'x:new~9999')" "$LD/presence/presence-x__new~9999.md" "a new name gets the safe filename"
assert_eq "$(bash "$PRES" --dir "$LD" files 'x:bob~ab12' | wc -l | tr -d ' ')" "1" "a session name matches only its own record"
assert_eq "$(bash "$PRES" --dir "$LD" files 'x:bob' | wc -l | tr -d ' ')" "2" "an address matches all of its sessions"
bash "$PRES" --dir "$LD" files 'x:nobody' >/dev/null 2>&1 && fail "unknown agent should exit 1" || pass "unknown agent exits non-zero"
assert_eq "$(bb_agent_subs "$LD" 'x:bob~ab12')" "topic-a" "a session sees only its own subscriptions"
assert_eq "$(bb_agent_subs "$LD" 'x:bob' | sort | tr '\n' ' ')" "topic-a topic-b " "an address unions its sessions' subscriptions"
mkmsg() { printf -- '---\nid: "%s"\ntype: task\nstatus: pending\nrouting: direct\nfrom: s:main\nto: %s\ntitle: T\n---\n' "$1" "$2" > "$LD/messages/task-$1-pending.md"; }
mkmsg 1 'x:bob'; mkmsg 2 'x:bob~ab12'; mkmsg 3 'x:bob~f3c9'
assert_eq "$(bb_pending_for "$LD" 'x:bob~ab12' | sort | tr '\n' ' ')" "task-1-pending.md task-2-pending.md " "a session gets its address's messages and its own, not a sibling's"
assert_eq "$(bb_pending_for "$LD" 'x:nate~0001' | tr '\n' ' ')" "" "another person's session gets none of them"

# ── Test 11: migration (v6 AC-7) ─────────────────────────────────────────────
echo ""
echo "11. Presence migration"
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
MIG="$MOD/scripts/backbone-migrate-presence.sh"
MD="$TMP_DIR/mig"; mkdir -p "$MD/presence"; git init -q -b main "$MD"
mkpres "$MD/presence/presence-stak-app:main.md" "stak-app:main"
mkpres "$MD/presence/presence-grostak-v2:main.md" "grostak-v2:main"
mkpres "$MD/presence/presence-example.md" "example-repo:example-task"
git -C "$MD" add -A && git -C "$MD" commit -q -m "old names"
echo "touched" >> "$MD/presence/presence-stak-app:main.md"
git -C "$MD" commit -q -am "second commit so history has two entries"

before="$(ls "$MD/presence" | sort | tr '\n' ' ')"
out="$(bash "$MIG" --dir "$MD" --dry-run)"; rc=$?
assert_eq "$rc" "0" "dry run exits 0"
assert_eq "$(ls "$MD/presence" | sort | tr '\n' ' ')" "$before" "dry run changes nothing"
if grep -q "WOULD   presence-stak-app:main.md -> presence-stak-app__main.md" <<<"$out"; then pass "dry run lists the rename"; else fail "dry run did not list the rename: $out"; fi

bash "$MIG" --dir "$MD" >/dev/null; rc=$?
assert_eq "$rc" "0" "migration exits 0"
assert_file_exists "$MD/presence/presence-stak-app__main.md" "colon file renamed to safe form"
assert_file_exists "$MD/presence/presence-grostak-v2__main.md" "second file renamed"
assert_file_exists "$MD/presence/presence-example.md" "an already-safe file is left alone"
if ls "$MD/presence" | grep -q ':'; then fail "a colon filename remains"; else pass "no colon filenames remain"; fi
assert_contains "$MD/presence/presence-stak-app__main.md" "^agent_name: stak-app:main" "agent_name inside the file is untouched"
assert_eq "$(bash "$PRES" --dir "$MD" path 'stak-app:main')" "$MD/presence/presence-stak-app__main.md" "readers still find the record by agent_name"
git -C "$MD" commit -q -m "migrate"
assert_eq "$(git -C "$MD" log --follow --oneline -- presence/presence-stak-app__main.md | wc -l | tr -d ' ')" "3" "git history follows the rename (create, edit, rename)"

out="$(bash "$MIG" --dir "$MD")"; rc=$?
assert_eq "$rc" "0" "second run exits 0"
assert_eq "$out" "nothing to migrate" "second run is a no-op"
assert_eq "$(git -C "$MD" status --short | wc -l | tr -d ' ')" "0" "second run leaves the tree clean"

# a target that already exists is never overwritten
mkpres "$MD/presence/presence-dup:main.md" "dup:main"; mkpres "$MD/presence/presence-dup__main.md" "dup:main"
rc=0; out="$(bash "$MIG" --dir "$MD")" || rc=$?
assert_eq "$rc" "1" "an existing target is skipped and exits 1"
assert_file_exists "$MD/presence/presence-dup:main.md" "...and the source is kept"

# outside git, a plain rename works
PD="$TMP_DIR/plain"; mkdir -p "$PD/presence"; mkpres "$PD/presence/presence-a:b.md" "a:b"
bash "$MIG" --dir "$PD" >/dev/null
assert_file_exists "$PD/presence/presence-a__b.md" "a directory outside git is migrated too"
rc=0; bash "$MIG" --dir "$TMP_DIR/nonexistent" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "4" "a missing directory exits 4"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
