#!/usr/bin/env bash
# Tests the v5 git transport: sync wrapper, race-safe claim, transport setting,
# notification scripts, secret check. Uses real git with two clones of a local bare
# repo — no mocks.
# Run from the aidev-toolkit root: bash tests/test-git-transport.sh

set -uo pipefail
exec </dev/null   # hooks read stdin; do not eat the script list that run-all.sh pipes in

MOD="$(cd "$(dirname "$0")/../modules/backbone" && pwd)"
SKILLS="$MOD/skills"
SYNC="$MOD/scripts/backbone-sync.sh"
TMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0

export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi; }
assert_file() { if [[ -f "$1" ]]; then pass "$2"; else fail "$2 (missing: $1)"; fi; }
assert_no_file() { if [[ ! -f "$1" ]]; then pass "$2"; else fail "$2 (should not exist: $1)"; fi; }
assert_contains() { if grep -q -- "$2" "$1" 2>/dev/null; then pass "$3"; else fail "$3 (pattern '$2' not in $1)"; fi; }
assert_match() { if [[ "$1" =~ $2 ]]; then pass "$3"; else fail "$3 (got '$1', wanted /$2/)"; fi; }

# make_msg <dir> <type> <id> <to>   — write a pending direct message
make_msg() {
  cat > "$1/messages/$2-$3-pending.md" <<EOF
---
id: "$3"
type: $2
status: pending
routing: direct
from: sender:main
to: $4
title: Test message $3
created: 2026-10-07
updated: 2026-10-07
---

Body of $3.
EOF
}

# claim_msg <dir> <type> <id> <agent> — rename pending to claimed, recording claimed_by
claim_msg() {
  sed -e 's/^status: pending/status: claimed/' -e "s/^updated:.*/updated: 2026-10-07\nclaimed_by: $4/" \
    "$1/messages/$2-$3-pending.md" > "$1/messages/$2-$3-claimed.md"
  rm "$1/messages/$2-$3-pending.md"
}

# new_world — fresh bare remote and two synced clones in transport=git mode
new_world() {
  rm -rf "$TMP_DIR/w"; mkdir -p "$TMP_DIR/w"
  BARE="$TMP_DIR/w/remote.git"; A="$TMP_DIR/w/a"; B="$TMP_DIR/w/b"
  git init -q --bare -b main "$BARE"
  git clone -q "$BARE" "$A" 2>/dev/null
  mkdir -p "$A/messages" "$A/presence"; touch "$A/messages/.gitkeep" "$A/presence/.gitkeep"
  git -C "$A" add -A && git -C "$A" commit -q -m "init" && git -C "$A" push -q origin HEAD:main
  git -C "$A" branch -q -M main 2>/dev/null; git -C "$A" branch -q --set-upstream-to=origin/main main 2>/dev/null
  git clone -q "$BARE" "$B" 2>/dev/null
  echo "transport=git" > "$A/backbone.config"; echo "transport=git" > "$B/backbone.config"
}

echo ""
echo "Git Transport Tests"
echo "==================="

# ── 1. Transport setting ──────────────────────────────────────────────────────
echo ""
echo "1. Transport setting (AC-11, AC-12)"
new_world
rm -f "$B/backbone.config"
assert_eq "$("$SYNC" --dir "$B" mode)" "local" "no backbone.config defaults to local"
echo "transport=local" > "$B/backbone.config"
before="$(git -C "$B" rev-parse HEAD)"
make_msg "$B" task 100 "a:main"
"$SYNC" --dir "$B" push publish task-100; rc=$?
assert_eq "$rc" "0" "local-mode push exits 0"
assert_eq "$(git -C "$B" rev-parse HEAD)" "$before" "local mode makes no commit even though a remote exists"
assert_eq "$(git -C "$BARE" log --oneline | wc -l | tr -d ' ')" "1" "local mode pushes nothing to the remote"
assert_file "$B/messages/task-100-pending.md" "local mode leaves the message on disk"
rm "$B/messages/task-100-pending.md"
echo "transport=carrier-pigeon" > "$B/backbone.config"
"$SYNC" --dir "$B" mode >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "invalid transport value fails loudly (exit 4)"
echo "transport=git" > "$B/backbone.config"
assert_eq "$("$SYNC" --dir "$B" mode)" "git" "transport=git is honored"

# ── 2. Publish and receive (AC-1, AC-3) ───────────────────────────────────────
echo ""
echo "2. Publish and receive over git (AC-1, AC-3)"
new_world
make_msg "$A" task 200 "b:main"
"$SYNC" --dir "$A" push publish task-200; rc=$?
assert_eq "$rc" "0" "publish push succeeds"
assert_eq "$(git -C "$BARE" log -1 --format=%s main)" "backbone: publish task-200" "publish commit message is 'backbone: publish task-200'"
assert_no_file "$B/messages/task-200-pending.md" "B does not see it before pulling"
"$SYNC" --dir "$B" pull; rc=$?
assert_eq "$rc" "0" "B pull succeeds"
assert_file "$B/messages/task-200-pending.md" "B sees the message after pull, no manual git step"
assert_eq "$(git -C "$A" ls-files backbone.config | wc -l | tr -d ' ')" "0" "backbone.config is never committed"

# ── 3. Race-safe claim (AC-2, AC-3) ───────────────────────────────────────────
echo ""
echo "3. Concurrent claim: exactly one wins (AC-2)"
claim_msg "$A" task 200 "a:main"
claim_msg "$B" task 200 "b:main"
"$SYNC" --dir "$A" push claim task-200; rcA=$?
"$SYNC" --dir "$B" push claim task-200 2>"$TMP_DIR/loser.err"; rcB=$?
assert_eq "$rcA" "0" "first claimer's push succeeds"
assert_eq "$rcB" "3" "second claimer's push is rejected as a lost race (exit 3)"
assert_contains "$TMP_DIR/loser.err" "lost the race" "loser is told it lost the race"
assert_file "$B/messages/task-200-claimed.md" "loser's tree now holds the winner's claimed file"
assert_contains "$B/messages/task-200-claimed.md" "claimed_by: a:main" "loser sees the winner as claimed_by"
assert_no_file "$B/messages/task-200-pending.md" "loser has no stale pending copy"
assert_eq "$(git -C "$BARE" log --format=%s main | grep -c 'backbone: claim task-200')" "1" "remote has exactly one claim commit"
assert_eq "$(git -C "$B" status --porcelain | grep -v backbone.config | wc -l | tr -d ' ')" "0" "loser's working tree is clean after re-sync"

# ── 4. Complete (AC-3) ────────────────────────────────────────────────────────
echo ""
echo "4. Complete and archive"
mkdir -p "$A/messages/archive"
git -C "$A" mv -f messages/task-200-claimed.md messages/archive/task-200-complete.md 2>/dev/null || mv "$A/messages/task-200-claimed.md" "$A/messages/archive/task-200-complete.md"
"$SYNC" --dir "$A" push complete task-200; rc=$?
assert_eq "$rc" "0" "complete push succeeds"
assert_eq "$(git -C "$BARE" log -1 --format=%s main)" "backbone: complete task-200" "complete commit message matches AC-3"
"$SYNC" --dir "$B" pull
assert_file "$B/messages/archive/task-200-complete.md" "B receives the archived message"
assert_no_file "$B/messages/task-200-claimed.md" "claimed copy is gone on B"

# ── 5. Unreachable remote (AC-12) ─────────────────────────────────────────────
echo ""
echo "5. Unreachable remote: fail loudly in git mode, ignore in local mode"
new_world
git -C "$A" remote set-url origin "$TMP_DIR/w/does-not-exist.git"
make_msg "$A" task 300 "b:main"
"$SYNC" --dir "$A" pull 2>"$TMP_DIR/pull.err"; rc=$?
assert_eq "$rc" "2" "pull with unreachable remote exits 2 (no silent fallback)"
assert_contains "$TMP_DIR/pull.err" "unreachable" "pull error says the remote is unreachable"
"$SYNC" --dir "$A" push publish task-300 2>"$TMP_DIR/push.err"; rc=$?
assert_eq "$rc" "2" "push with unreachable remote exits 2"
assert_eq "$(git -C "$A" log -1 --format=%s)" "backbone: publish task-300" "commit is kept locally when the push fails"
echo "transport=local" > "$A/backbone.config"
"$SYNC" --dir "$A" pull; rc=$?
assert_eq "$rc" "0" "flipping to transport=local makes the same bad remote irrelevant"
echo "transport=git" > "$A/backbone.config"
git -C "$A" remote set-url origin "$BARE"
"$SYNC" --dir "$A" push publish task-300; rc=$?
assert_eq "$rc" "0" "re-running push after the remote returns delivers the kept commit"
"$SYNC" --dir "$B" pull
assert_file "$B/messages/task-300-pending.md" "B receives the message that was queued locally"

# make_topic_msg <dir> <type> <id> <topic> — write a pending topic message
make_topic_msg() {
  cat > "$1/messages/$2-$3-pending.md" <<EOF
---
id: "$3"
type: $2
status: pending
routing: topic
from: sender:main
topic: $4
title: Topic message $3
created: 2026-10-07
updated: 2026-10-07
---

Body of $3.
EOF
}

# ── 6. Session start (AC-4) ───────────────────────────────────────────────────
echo ""
echo "6. SessionStart pending count (AC-4)"
new_world
SESSION="$MOD/scripts/backbone-session-start.sh"
printf -- '---\nagent_name: b:main\nsubscriptions:\n  - schema-changes\n---\n' > "$B/presence/presence-b__main.md"
make_msg "$A" task 601 "b:main"
make_msg "$A" task 602 "a:main"
make_msg "$A" task 603 "any"
make_topic_msg "$A" task 604 "schema-changes"
make_topic_msg "$A" task 605 "unsubscribed-topic"
"$SYNC" --dir "$A" push publish task-601 >/dev/null
out="$("$SESSION" --dir "$B" --agent "b:main" --key t6 </dev/null)"; rc=$?
assert_eq "$rc" "0" "session-start exits 0"
assert_match "$(head -1 <<<"$out")" '^backbone: 3 pending message\(s\) for b:main~[a-z0-9]{4}$' "count is the first output line (direct + any + subscribed topic)"
assert_eq "$(grep -c 'task-60[134]' <<<"$out")" "3" "lists the three addressed messages"
assert_eq "$(grep -c 'task-60[25]' <<<"$out")" "0" "does not list messages for other agents or unsubscribed topics"
assert_file "$B/messages/task-601-pending.md" "session-start pulled the messages from the remote"
"$SYNC" --dir "$A" pull
assert_match "$(ls "$A/messages/seen")" 'task-601\.b__main~[a-z0-9]{4}' "seen marker reached the sender via git"
assert_match "$(ls "$A/messages/seen")" 'task-604\.b__main~[a-z0-9]{4}' "seen marker written for the topic message too"
mkdir -p "$TMP_DIR/noproj"
out="$(BACKBONE_AGENT= "$SESSION" --dir "$B" --project "$TMP_DIR/noproj" --key t6b </dev/null)"; rc=$?
assert_eq "$rc" "0" "session-start without an agent name still exits 0"
assert_contains <(echo "$out") "no agent name" "...and says why the count was skipped"
echo "agent=b:main" >> "$B/backbone.config"
assert_match "$("$SESSION" --dir "$B" --key t6c </dev/null | head -1)" '^backbone: 3 pending message\(s\) for b:main~' "agent= in backbone.config is honored"

# ── 7. Poll (AC-5) ────────────────────────────────────────────────────────────
echo ""
echo "7. Monitor poll: silent when idle, fires on a new addressed message (AC-5)"
new_world
POLL="$MOD/scripts/backbone-poll.sh"
out="$("$POLL" --dir "$B" --agent "b:main" --interval 1 --max-iterations 2)"; rc=$?
assert_eq "$out" "" "idle poll prints nothing"
assert_eq "$rc" "1" "idle poll gives up with exit 1 after --max-iterations"
make_msg "$A" task 700 "b:main"; "$SYNC" --dir "$A" push publish task-700 >/dev/null
"$POLL" --dir "$B" --agent "b:main" --interval 1 --max-iterations 2 >"$TMP_DIR/poll0.out"; rc=$?
assert_eq "$(cat "$TMP_DIR/poll0.out")" "" "a message already pending at startup does not fire the poll"
"$POLL" --dir "$B" --agent "b:main" --interval 1 --max-iterations 10 >"$TMP_DIR/poll.out" 2>&1 &
ppid=$!
sleep 1.5
make_msg "$A" task 701 "a:main"; "$SYNC" --dir "$A" push publish task-701 >/dev/null
sleep 2.5
assert_eq "$(cat "$TMP_DIR/poll.out")" "" "poll stays silent for a message addressed to someone else"
assert_no_file "$B/messages/task-701-pending.md" "watching does not modify the working tree (fetch only)"
make_msg "$A" task 702 "b:main"; "$SYNC" --dir "$A" push publish task-702 >/dev/null
wait "$ppid"; rc=$?
assert_eq "$rc" "0" "poll exits 0 when an addressed message arrives"
assert_eq "$(wc -l < "$TMP_DIR/poll.out" | tr -d ' ')" "1" "poll printed exactly one line"
assert_contains "$TMP_DIR/poll.out" "task-702 from sender:main: Test message 702" "line names the message, sender, and title"
"$SYNC" --dir "$A" pull
assert_file "$A/messages/seen/task-702.b__main" "poll hit wrote and pushed the seen marker"

# ── 8. Agent-to-human map ─────────────────────────────────────────────────────
echo ""
echo "8. Roster: agent-to-human map"
new_world
LOOKUP="$MOD/scripts/backbone-roster-lookup.sh"
assert_eq "$("$LOOKUP" --dir "$A" "b:main"; echo "rc=$?")" "rc=1" "no roster.md means no match (exit 1)"
cat > "$A/roster.md" <<'EOF'
# Roster

| agent | human | notify |
| ----- | ----- | ----- |
| `a:*` | Bob | bob@example.com |
| b:* | Nate | nate@example.com |
EOF
assert_eq "$("$LOOKUP" --dir "$A" "a:refill-flow")" "Bob|bob@example.com" "glob row matches any task name for a repo"
assert_eq "$("$LOOKUP" --dir "$A" "b:main")" "Nate|nate@example.com" "second row matches"
"$LOOKUP" --dir "$A" "zzz:main" >/dev/null; rc=$?
assert_eq "$rc" "1" "unknown agent exits 1"

# ── 9. No-ack ping (AC-6) ─────────────────────────────────────────────────────
echo ""
echo "9. No-ack ping after the timeout (AC-6)"
ACK="$MOD/scripts/backbone-ack-check.sh"
ackcmd() { "$ACK" --dir "$A" --id "$1" --to "b:main" --from "a:main" --title "Test message ${1#task-}" --interval 1 "${@:2}"; }
echo "notify_command=true" >> "$A/backbone.config"   # a notifier must exist for the timer to ping (AC-4)
make_msg "$A" task 900 "b:main"; "$SYNC" --dir "$A" push publish task-900 >/dev/null
out="$(ackcmd task-900 --timeout 2)"; rc=$?
assert_eq "$rc" "10" "no ack within the timeout exits 10 (ask is the default)"
assert_eq "$out" 'PING Nate|nate@example.com :: a:main sent you "Test message 900" on the backbone (task-900)' "ping names sender and title"
if grep -q "Body of" <<<"$out"; then fail "ping must not contain the message body"; else pass "ping contains no message body"; fi
out="$(cd "$A" && mv roster.md roster.md.off && "$ACK" --dir "$A" --id task-900 --to b:main --from a:main --title T --timeout 1 --interval 1)"; rc=$?
mv "$A/roster.md.off" "$A/roster.md"
assert_eq "$rc" "11" "no roster entry exits 11 with NOPING"
assert_contains <(echo "$out") "NOPING" "...and says there is nobody to ping"
"$MOD/scripts/backbone-session-start.sh" --dir "$B" --agent "b:main" >/dev/null
out="$(ackcmd task-900 --timeout 3)"; rc=$?
assert_eq "$rc" "0" "a seen marker counts as an ack"
assert_eq "$out" "" "...and nothing is printed"
make_msg "$A" task 901 "b:main"; "$SYNC" --dir "$A" push publish task-901 >/dev/null
"$SYNC" --dir "$B" pull; claim_msg "$B" task 901 "b:main"; "$SYNC" --dir "$B" push claim task-901 >/dev/null
out="$(ackcmd task-901 --timeout 3)"; rc=$?
assert_eq "$rc" "0" "a claim counts as an ack"
make_msg "$A" task 902 "b:main"; "$SYNC" --dir "$A" push publish task-902 >/dev/null
( ackcmd task-902 --timeout 20 >"$TMP_DIR/ack.out"; echo $? >"$TMP_DIR/ack.rc" ) &
apid=$!
sleep 2
start=$SECONDS
"$MOD/scripts/backbone-session-start.sh" --dir "$B" --agent "b:main" >/dev/null
wait "$apid"
assert_eq "$(cat "$TMP_DIR/ack.rc")" "0" "an ack that arrives mid-wait ends the timer with exit 0"
assert_eq "$(cat "$TMP_DIR/ack.out")" "" "...with no ping sent"
if [[ $((SECONDS - start)) -lt 15 ]]; then pass "timer stopped as soon as the ack arrived, not at the timeout"; else fail "timer ran to the timeout"; fi

# ── 10. Secret check (AC-7) ───────────────────────────────────────────────────
echo ""
echo "10. Secret check on publish (AC-7)"
SECRET="$MOD/scripts/backbone-secret-check.sh"
# Fixtures are assembled at runtime so this file holds no literal secrets.
tok48="aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5bC7dE9fG1hJ3"
cases_bad=(
  "mongodb+srv://admin:Hunter2pass@cluster0.example.net/app|connection string"
  "postgres://svc:pw123456@db.internal:5432/prod|connection string"
  "Authorization: Bearer abcdef0123456789abcdef0123|bearer token"
  "-----BEGIN RSA ""PRIVATE KEY-----|private key"
  "key AKIA""ABCDEFGHIJKLMNOP is set|AWS access key"
  "token gh""p_abcdefghijklmnopqrstuvwxyz0123456789 end|GitHub token"
  "the value is $tok48 ok|long base64-like token"
)
for c in "${cases_bad[@]}"; do
  text="${c%|*}"; label="${c##*|}"
  printf 'first line\n%s\nlast line\n' "$text" > "$TMP_DIR/body.md"
  out="$("$SECRET" "$TMP_DIR/body.md")"; rc=$?
  assert_eq "$rc" "1" "flags $label"
  assert_contains <(echo "$out") "line 2:" "...and reports the line number ($label)"
  if grep -qF -- "${text:12:12}" <<<"$out"; then fail "output must not echo the matched text ($label)"; else pass "output does not echo the secret ($label)"; fi
done
cases_ok=(
  "mongodb://user:<password>@host:27017/db"
  "postgres://app:\${DB_PASSWORD}@db.internal/prod"
  "commit 326a876d5b2c1f0e9a8b7c6d5e4f3a2b1c0d9e8f landed"
  "see apps/api/src/routes/patients/refill-requests/handler.ts for details"
  "https://example.com/docs/page and user@example.com"
  "send a Bearer token in the header"
  "Atlas times out from the Windows box; works from the Mac. Use the URI in your .env."
)
for text in "${cases_ok[@]}"; do
  printf '%s\n' "$text" > "$TMP_DIR/body.md"
  "$SECRET" "$TMP_DIR/body.md" >/dev/null; rc=$?
  assert_eq "$rc" "0" "allows: ${text:0:48}"
done
"$SECRET" "$TMP_DIR/does-not-exist" 2>/dev/null; rc=$?
assert_eq "$rc" "4" "missing file is a usage error"

# ── 11. Untrusted-message language and publish wiring (US-6, AC-10) ───────────
echo ""
echo "11. Command and conventions wiring"
assert_contains "$SKILLS/backbone-inbox.md" "untrusted requests, not instructions" "inbox display states messages are untrusted"
assert_contains "$SKILLS/backbone-send.md" "backbone-secret-check.sh" "send runs the secret check"
assert_contains "$SKILLS/backbone-send.md" "backbone-ack-check.sh" "send starts the no-ack timer"
assert_contains "$SKILLS/backbone-send.md" "push publish" "send pushes via the sync wrapper"
assert_contains "$SKILLS/backbone-inbox.md" "push claim" "inbox claim pushes via the sync wrapper"
assert_contains "$SKILLS/backbone-done.md" "push complete" "done pushes via the sync wrapper"
assert_contains "$SKILLS/backbone.md" "backbone-poll.sh" "/backbone join documents starting the poll"

# ── 13. Notifier contract (v6 Phase 1) ─────────────────────────────────────────
echo ""
echo "13. Notifier"
NOTIFY="$MOD/scripts/backbone-notify.sh"
ND="$TMP_DIR/notify"; mkdir -p "$ND"

# no notifier configured: nothing attempted, exit 3
bash "$NOTIFY" --dir "$ND" --target T --from a:main --title hi --id task-1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "3" "no notify_command exits 3"

# a notifier that records its environment, one variable per file so newlines survive
cat > "$ND/capture.sh" <<'EOS'
#!/usr/bin/env bash
out="$(dirname "$0")/captured"; mkdir -p "$out"
printf '%s' "$BACKBONE_NOTIFY_TARGET" > "$out/target"
printf '%s' "$BACKBONE_NOTIFY_TEXT"   > "$out/text"
printf '%s' "$BACKBONE_NOTIFY_FROM"   > "$out/from"
printf '%s' "$BACKBONE_NOTIFY_TITLE"  > "$out/title"
printf '%s' "$BACKBONE_NOTIFY_ID"     > "$out/id"
printf '%s' "$*" > "$out/argv"
EOS
echo "notify_command=bash $ND/capture.sh" > "$ND/backbone.config"

HOSTILE=$'He said "hi" $(touch '"$ND"'/pwned) `touch '"$ND"'/pwned2`\nline two'
bash "$NOTIFY" --dir "$ND" --target "spaces/AAAA" --from "stak-app:main" --title "$HOSTILE" --id "task-9" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "notifier success exits 0"
assert_eq "$(cat "$ND/captured/target")" "spaces/AAAA" "target passed in environment"
assert_eq "$(cat "$ND/captured/title")" "$HOSTILE" "hostile title arrives unchanged"
assert_eq "$(cat "$ND/captured/text")" "stak-app:main sent you \"$HOSTILE\" on the backbone (task-9)" "text built from sender, title, id"
assert_no_file "$ND/pwned" "\$(...) in title not executed"
assert_no_file "$ND/pwned2" "backticks in title not executed"
assert_eq "$(cat "$ND/captured/argv")" "" "no text passed as command arguments"

# a failing notifier is reported, not hidden
echo "notify_command=false" > "$ND/backbone.config"
bash "$NOTIFY" --dir "$ND" --target T --from a:main --title hi --id task-2 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "1" "failing notifier exits 1"

# missing required args
bash "$NOTIFY" --dir "$ND" --from a:main >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "missing --target/--id exits 4"

# ── 14. notify_confirm resolution (v6 Phase 1) ─────────────────────────────────
echo ""
echo "14. notify_confirm precedence"
source "$MOD/scripts/backbone-lib.sh"
CD="$TMP_DIR/confirm"; mkdir -p "$CD"

assert_eq "$(bb_notify_confirm "$CD" stak-app:main)" "ask" "no config defaults to ask"

printf 'notify_confirm=auto\n' > "$CD/backbone.config"
assert_eq "$(bb_notify_confirm "$CD" stak-app:main)" "auto" "machine default auto applies"

printf 'notify_confirm=auto\nnotify_confirm.radeas-analyst-amplifier=ask\n' > "$CD/backbone.config"
assert_eq "$(bb_notify_confirm "$CD" radeas-analyst-amplifier:main)" "ask" "project override beats machine default"
assert_eq "$(bb_notify_confirm "$CD" stak-app:main)" "auto" "other projects keep machine default"

printf 'notify_confirm=ask\nnotify_confirm.stak-app=auto\n' > "$CD/backbone.config"
assert_eq "$(bb_notify_confirm "$CD" stak-app:feature-x)" "auto" "override applies to any agent in the project"

printf 'notify_confirm.my.app=auto\n' > "$CD/backbone.config"
assert_eq "$(bb_notify_confirm "$CD" myXapp:main)" "ask" "dot in project key is literal"
assert_eq "$(bb_notify_confirm "$CD" my.app:main)" "auto" "dotted project name matches itself"

printf 'notify_confirm=sometimes\n' > "$CD/backbone.config"
bb_notify_confirm "$CD" a:main >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "invalid value is an error"

printf '  notify_confirm = auto \r\n# notify_confirm=ask\n' > "$CD/backbone.config"
assert_eq "$(bb_notify_confirm "$CD" a:main)" "auto" "whitespace, CR and comments tolerated"

# overrides are never read from a project repo
mkdir -p "$CD/proj"; printf 'notify_confirm.proj=auto\n' > "$CD/proj/backbone.config"
: > "$CD/backbone.config"
assert_eq "$(bb_notify_confirm "$CD" proj:main)" "ask" "config inside a project directory is ignored"

# ── 15. Ping delivery: ask vs auto, overrides, failure, logging (v6 Phase 1) ──
echo ""
echo "15. Ping delivery"
new_world
cat > "$A/roster.md" <<'EOF'
| agent | human | notify |
| ----- | ----- | ------ |
| b:* | Nate | spaces/NATE |
EOF
cat > "$TMP_DIR/rec.sh" <<'EOS'
#!/usr/bin/env bash
out="$(dirname "$0")/rec"; mkdir -p "$out"
printf '%s' "$BACKBONE_NOTIFY_TARGET" > "$out/target"
printf '%s' "$BACKBONE_NOTIFY_TEXT" > "$out/text"
printf '%s' "$BACKBONE_NOTIFY_TITLE" > "$out/title"
echo ran >> "$out/runs"
EOS
HOSTILE=$'Q "x" $(touch '"$TMP_DIR"'/pwned3) `touch '"$TMP_DIR"'/pwned4`\nline two'
BODY_MARK="SECRET-BODY-TEXT"
make_msg "$A" task 950 "b:main"; echo "$BODY_MARK" >> "$A/messages/task-950-pending.md"; "$SYNC" --dir "$A" push publish task-950 >/dev/null
ack15() { "$ACK" --dir "$A" --id task-950 --to b:main --from "${FROM15:-a:main}" --title "${TITLE15:-plain}" --timeout 1 --interval 1; }
LOG="$A/.claude/data/backbone/pings.log"

# no notifier: nothing attempted, in both modes
out="$(ack15)"; rc=$?
assert_eq "$rc" "14" "no notify_command exits 14"
assert_contains <(echo "$out") "NONOTIFIER" "...and says no notifier is configured"
assert_no_file "$LOG" "...and nothing is logged (nothing was attempted)"
printf 'transport=git\nnotify_confirm=auto\n' > "$A/backbone.config"
out="$(ack15)"; rc=$?
assert_eq "$rc" "14" "auto without a notifier still exits 14 and sends nothing"

# ask (the default): PING printed, notifier NOT run
rm -rf "$TMP_DIR/rec"
printf 'transport=git\nnotify_command=bash %s\n' "$TMP_DIR/rec.sh" > "$A/backbone.config"
out="$(ack15)"; rc=$?
assert_eq "$rc" "10" "ask mode (default) exits 10 with a PING"
assert_eq "$out" 'PING Nate|spaces/NATE :: a:main sent you "plain" on the backbone (task-950)' "PING shows the exact target and text"
assert_no_file "$TMP_DIR/rec/runs" "ask mode does not run the notifier"

# auto via the machine default: notifier runs once with env vars
printf 'transport=git\nnotify_command=bash %s\nnotify_confirm=auto\n' "$TMP_DIR/rec.sh" > "$A/backbone.config"
TITLE15="$HOSTILE" out="$(ack15)"; rc=$?
assert_eq "$rc" "12" "auto mode exits 12 when sent"
assert_eq "$out" "SENT Nate|spaces/NATE :: task-950" "SENT line names the target and id only"
assert_eq "$(wc -l < "$TMP_DIR/rec/runs" | tr -d ' ')" "1" "notifier ran exactly once"
assert_eq "$(cat "$TMP_DIR/rec/target")" "spaces/NATE" "target from the roster reaches the notifier"
assert_eq "$(cat "$TMP_DIR/rec/title")" "$HOSTILE" "hostile title arrives unchanged through the ack check"
assert_no_file "$TMP_DIR/pwned3" "\$(...) in a title is not executed"
assert_no_file "$TMP_DIR/pwned4" "backticks in a title are not executed"

# per-project override beats the machine default, in both directions
rm -rf "$TMP_DIR/rec"
printf 'transport=git\nnotify_command=bash %s\nnotify_confirm=auto\nnotify_confirm.a=ask\n' "$TMP_DIR/rec.sh" > "$A/backbone.config"
out="$(ack15)"; rc=$?
assert_eq "$rc" "10" "project override ask beats machine default auto"
assert_no_file "$TMP_DIR/rec/runs" "...and the notifier did not run"
printf 'transport=git\nnotify_command=bash %s\nnotify_confirm.a=auto\n' "$TMP_DIR/rec.sh" > "$A/backbone.config"
out="$(ack15)"; rc=$?
assert_eq "$rc" "12" "project override auto beats the ask default"
FROM15="other:main" out="$(ack15)"; rc=$?
assert_eq "$rc" "10" "another project keeps the ask default"
printf 'transport=git\nnotify_command=bash %s\nnotify_confirm=sometimes\n' "$TMP_DIR/rec.sh" > "$A/backbone.config"
out="$(ack15)"; rc=$?
assert_eq "$rc" "4" "an invalid notify_confirm is an error, not a silent default"

# notifier failure in auto is reported, not hidden
printf 'transport=git\nnotify_command=false\nnotify_confirm=auto\n' > "$A/backbone.config"
out="$(ack15)"; rc=$?
assert_eq "$rc" "13" "failing notifier in auto exits 13"
assert_contains <(echo "$out") "NOTIFYFAILED" "...and prints NOTIFYFAILED"

# the log has target, id and result, and never the title, text or body
assert_file "$LOG" "ping attempts are logged"
assert_contains "$LOG" "sent	spaces/NATE	task-950" "sent attempt logged with target and id"
assert_contains "$LOG" "failed	spaces/NATE	task-950" "failed attempt logged"
if grep -qE "plain|Q \"x\"|$BODY_MARK|sent you" "$LOG"; then fail "log must not hold title, text or body"; else pass "log holds no title, text or body"; fi
printf 'transport=git\nnotify_command=bash %s\nnotify_confirm=auto\n' "$TMP_DIR/rec.sh" > "$A/backbone.config"
all="$(ack15 2>&1; bash "$NOTIFY" --dir "$A" --target T --from a:main --title t --id task-950 2>&1)"
if grep -q "$BODY_MARK" <<<"$all"; then fail "message body leaked into output"; else pass "message body appears in no script output"; fi

# ── 16. Session hooks: register, re-join, end (v6 Phase 3, AC-8) ───────────────
echo ""
echo "16. Session hooks"
new_world
SSTART="$MOD/scripts/backbone-session-start.sh"
SEND="$MOD/scripts/backbone-session-end.sh"
PROJ="$TMP_DIR/proj/myrepo"; mkdir -p "$PROJ"; git init -q "$PROJ"; git -C "$PROJ" config user.name "Bob Seaton"
npres() { ls "$1/presence" | grep -c '^presence-.*\.md$'; }

# first join: inferred address, unique session name, count first, watcher instruction, no colon in filenames
out="$(cd "$TMP_DIR" && "$SSTART" --dir "$B" --project "$PROJ" --key k1 </dev/null)"; rc=$?
assert_eq "$rc" "0" "first join exits 0"
assert_match "$(head -1 <<<"$out")" '^backbone: 0 pending message\(s\) for myrepo:bob-seaton~[a-z0-9]{4}$' "count is the first line; name is <repo>:<git user>~<suffix>"
S1="$(sed -n 's/^backbone: 0 pending message(s) for //p' <<<"$out")"
assert_match "$out" 'name inferred' "an inferred name is reported as inferred"
assert_match "$out" "start the watcher now with the Monitor tool: bash .*backbone-poll.sh.* --agent \"$S1\"" "the agent is told how to start the watcher"
assert_match "$out" "others can address you as myrepo:bob-seaton" "the stable address is shown"
PF1="$(bash "$MOD/scripts/backbone-presence.sh" --dir "$B" path "$S1")"
assert_file "$PF1" "presence record written without any command"
assert_contains "$PF1" "^agent_name: $S1$" "agent_name holds the real session name"
assert_contains "$PF1" "^status: active" "...and status is active"
if ls "$B/presence" | grep -q ':'; then fail "a presence filename contains a colon"; else pass "no colon in any presence filename"; fi
assert_eq "$(cat "$B/.claude/data/backbone/sessions/k1")" "$S1" "the session name is remembered for the end hook"

# idempotent re-join: same session key, same record, prose survives
joined1="$(sed -n 's/^joined: //p' "$PF1")"
printf '\nMy own note.\n' >> "$PF1"
sleep 1
out="$("$SSTART" --dir "$B" --project "$PROJ" --key k1 </dev/null)"
assert_eq "$(sed -n 's/^backbone: 0 pending message(s) for //p' <<<"$out")" "$S1" "re-join keeps the same session name"
assert_eq "$(npres "$B")" "1" "re-join creates no second record"
assert_eq "$(sed -n 's/^joined: //p' "$PF1")" "$joined1" "re-join keeps the original joined time"
assert_contains "$PF1" "My own note." "re-join keeps prose written during the session"
assert_match "$out" "refreshed $S1" "re-join says it refreshed"

# a second Claude session for the same person is a second record under the same address
out="$("$SSTART" --dir "$B" --project "$PROJ" --key k2 </dev/null)"
S2="$(sed -n 's/^backbone: 0 pending message(s) for //p' <<<"$out")"
if [[ "$S2" != "$S1" && "$(bb_address "$S2")" == "myrepo:bob-seaton" ]]; then pass "a second session gets its own name under the same address"; else fail "second session name '$S2' vs '$S1'"; fi
assert_eq "$(npres "$B")" "2" "...and its own record"
assert_eq "$(bash "$MOD/scripts/backbone-presence.sh" --dir "$B" files myrepo:bob-seaton | wc -l | tr -d ' ')" "2" "the address resolves to both sessions"

# a message to the address reaches both sessions; one to a session reaches only it
make_msg "$A" task 1600 "myrepo:bob-seaton"; make_msg "$A" task 1601 "$S2"; "$SYNC" --dir "$A" push publish task-1600 >/dev/null
out1="$("$SSTART" --dir "$B" --project "$PROJ" --key k1 </dev/null | head -1)"
out2="$("$SSTART" --dir "$B" --project "$PROJ" --key k2 </dev/null | head -1)"
assert_match "$out1" 'backbone: 1 pending' "address message reaches session 1 (and not session 2's own)"
assert_match "$out2" 'backbone: 2 pending' "session 2 gets the address message and its own"
# a stdin session_id is used as the key
out="$(printf '{"hook_event_name":"SessionStart","session_id":"abc-123"}' | "$SSTART" --dir "$B" --project "$PROJ")"
assert_file "$B/.claude/data/backbone/sessions/abc-123" "the session_id from the hook's stdin keys the session"

# explicit address is honored and not called inferred
out="$("$SSTART" --dir "$B" --agent "radeas:nate" --project "$PROJ" --key k4 </dev/null)"
if grep -q 'name inferred' <<<"$out"; then fail "explicit address reported as inferred"; else pass "an explicit address is not reported as inferred"; fi
assert_match "$(head -1 <<<"$out")" 'for radeas:nate~' "...and is used as the address"

# end: marks inactive, pushes, forgets the session
"$SYNC" --dir "$B" push session-start x >/dev/null 2>&1
out="$("$SEND" --dir "$B" --key k1 </dev/null)"; rc=$?
assert_eq "$rc" "0" "session end exits 0"
assert_contains "$PF1" "^status: inactive" "session end marks presence inactive"
assert_contains "$PF1" "My own note." "...without touching the prose"
assert_no_file "$B/.claude/data/backbone/sessions/k1" "...and forgets the session"
"$SYNC" --dir "$A" pull
assert_contains "$A/presence/$(basename "$PF1")" "^status: inactive" "the inactive record was pushed to the remote"
assert_contains "$(bash "$MOD/scripts/backbone-presence.sh" --dir "$B" path "$S2")" "^status: active" "the other session stays active"
out="$("$SEND" --dir "$B" --key k1 </dev/null)"; rc=$?
assert_eq "$rc" "0" "ending twice exits 0"
assert_match "$out" "nothing to deregister" "...and says there is nothing to do"

# hooks never block the session, whatever fails
out="$("$SSTART" --dir "$TMP_DIR/does-not-exist" --key z </dev/null)"; rc=$?
assert_eq "$rc" "0" "start with a missing backbone dir exits 0"
out="$("$SEND" --dir "$TMP_DIR/does-not-exist" --key z </dev/null)"; rc=$?
assert_eq "$rc" "0" "end with a missing backbone dir exits 0"
out="$(printf 'not json at all \x00\xff' | "$SSTART" --dir "$B" --project "$PROJ")"; rc=$?
assert_eq "$rc" "0" "start with garbage on stdin exits 0"
assert_match "$(head -1 <<<"$out")" '^backbone: [0-9]+ pending' "...and the count is still the first line"
chmod 555 "$B/presence"
out="$("$SSTART" --dir "$B" --project "$PROJ" --key unwritable </dev/null)"; rc=$?
chmod 755 "$B/presence"
assert_eq "$rc" "0" "start with an unwritable presence dir exits 0"
assert_match "$(head -1 <<<"$out")" '^backbone: [0-9]+ pending' "...and the count is still the first line"
assert_match "$out" 'could not write' "...and says what failed"
git -C "$B" remote set-url origin "$TMP_DIR/no-such-remote.git"
out="$("$SSTART" --dir "$B" --project "$PROJ" --key k5 </dev/null)"; rc=$?
assert_eq "$rc" "0" "start with an unreachable remote exits 0"
assert_match "$(head -1 <<<"$out")" '^backbone: [0-9]+ pending' "...and the count is still the first line"
assert_match "$out" 'unreachable' "...and the outage is reported after it"
out="$("$SEND" --dir "$B" --key k5 </dev/null)"; rc=$?
assert_eq "$rc" "0" "end with an unreachable remote exits 0"
assert_contains "$(bash "$MOD/scripts/backbone-presence.sh" --dir "$B" path "$(sed -n 's/^backbone: [0-9]* pending message(s) for //p' <<<"$("$SSTART" --dir "$B" --project "$PROJ" --key k5 </dev/null)")")" "^status:" "the local record is still there after an outage"

# no explicit address and no git user: refuse, say why, exit 0
NOUSER="$TMP_DIR/nouser"; mkdir -p "$NOUSER"; git init -q "$NOUSER"
before="$(npres "$B")"
out="$(BACKBONE_AGENT= "$SSTART" --dir "$B" --project "$NOUSER" --key k6 </dev/null)"; rc=$?
assert_eq "$rc" "0" "refusing to register still exits 0"
assert_match "$out" 'none could be inferred' "...and explains how to fix it"
assert_eq "$(npres "$B")" "$before" "...and registers nothing"

# ── 17. Installing the hooks (v6 Phase 3) ───────────────────────────────────────
echo ""
echo "17. Hook installer"
IH="$MOD/scripts/backbone-install-hooks.sh"
P1="$TMP_DIR/hk1"; mkdir -p "$P1"
rc=0; bash "$IH" "$P1" </dev/null >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "5" "no consent and no terminal: exits 5"
assert_no_file "$P1/.claude/settings.json" "...and writes nothing"
bash "$IH" "$P1" --dry-run </dev/null >/dev/null; rc=$?
assert_eq "$rc" "0" "dry run exits 0"
assert_no_file "$P1/.claude/settings.json" "...and writes nothing"
bash "$IH" "$P1" --yes </dev/null >/dev/null; rc=$?
assert_eq "$rc" "0" "install with --yes exits 0"
assert_eq "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$P1/.claude/settings.json")" "bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-start.sh --dir ../agent-backbone" "SessionStart hook installed"
assert_eq "$(jq -r '.hooks.SessionEnd[0].hooks[0].command' "$P1/.claude/settings.json")" "bash ~/.claude/aidev-toolkit/modules/backbone/scripts/backbone-session-end.sh --dir ../agent-backbone" "SessionEnd hook installed"
cp "$P1/.claude/settings.json" "$TMP_DIR/hk1.before"
out="$(bash "$IH" "$P1" --yes </dev/null)"
assert_match "$out" 'already installed' "a second install says it is already installed"
assert_eq "$(jq -S . "$P1/.claude/settings.json")" "$(jq -S . "$TMP_DIR/hk1.before")" "...and changes nothing"

# merges into existing settings without losing anything
P2="$TMP_DIR/hk2"; mkdir -p "$P2/.claude"
cat > "$P2/.claude/settings.json" <<'EOF'
{"permissions":{"allow":["Bash(ls:*)"]},"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo mine"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo guard"}]}]}}
EOF
bash "$IH" "$P2" --yes </dev/null >/dev/null
assert_eq "$(jq -r '.permissions.allow[0]' "$P2/.claude/settings.json")" "Bash(ls:*)" "existing permissions are kept"
assert_eq "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$P2/.claude/settings.json")" "echo guard" "an unrelated existing hook is kept"
assert_eq "$(jq -r '.hooks.SessionStart | length' "$P2/.claude/settings.json")" "2" "the existing SessionStart hook is kept alongside the backbone one"
assert_eq "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$P2/.claude/settings.json")" "echo mine" "...and still runs first"
assert_file "$P2/.claude/settings.json.bak-backbone" "the previous settings were backed up"
assert_eq "$(jq -r '.hooks.SessionStart | length' "$P2/.claude/settings.json.bak-backbone")" "1" "...and the backup is the original"

# invalid JSON is never touched
P3="$TMP_DIR/hk3"; mkdir -p "$P3/.claude"; echo '{ not json' > "$P3/.claude/settings.json"
rc=0; bash "$IH" "$P3" --yes </dev/null >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "4" "invalid settings exit 4"
assert_eq "$(cat "$P3/.claude/settings.json")" "{ not json" "...and are left untouched"

# ── 18. Address, "me", and installing hooks (v6 Phase 4) ────────────────────────
echo ""
echo "18. Name, me, install --hooks"
NM="$MOD/scripts/backbone-name.sh"
ND2="$TMP_DIR/nm"; mkdir -p "$ND2"; printf '# keep me\ntransport=git\nagent=old\nnotify_command=true\n' > "$ND2/backbone.config"
assert_match "$(BACKBONE_AGENT= bash "$NM" --dir "$ND2" show)" 'address: old \(from agent=' "show reads agent= from the config"
bash "$NM" --dir "$ND2" set bob >/dev/null
assert_eq "$(bb_config_get "$ND2" agent)" "bob" "set replaces agent="
assert_eq "$(grep -c '^agent=' "$ND2/backbone.config")" "1" "...leaving exactly one agent= line"
assert_contains "$ND2/backbone.config" "^# keep me" "...and keeps comments"
assert_contains "$ND2/backbone.config" "^notify_command=true" "...and keeps other keys"
rc=0; bash "$NM" --dir "$ND2" set 'bad name;rm -rf' >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "4" "an address with shell characters is rejected"
rc=0; bash "$NM" --dir "$ND2" set 'bob~ab12' >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "4" "an address with a session suffix is rejected"
assert_eq "$(bb_config_get "$ND2" agent)" "bob" "...and the old value is untouched"
assert_match "$(BACKBONE_AGENT=envname bash "$NM" --dir "$ND2" show)" 'envname \(from BACKBONE_AGENT' "BACKBONE_AGENT wins over the config"
bash "$NM" --dir "$ND2" unset >/dev/null
assert_eq "$(bb_config_get "$ND2" agent)" "" "unset removes agent="
assert_contains "$ND2/backbone.config" "^transport=git" "...and keeps the rest"

new_world
PROJ2="$TMP_DIR/proj2/other"; mkdir -p "$PROJ2"; git init -q "$PROJ2"; git -C "$PROJ2" config user.name "Nate X"
rc=0; bash "$MOD/scripts/backbone-presence.sh" --dir "$B" me "$PROJ2" >/dev/null || rc=$?
assert_eq "$rc" "1" "me finds nothing before a session registers"
out="$("$SSTART" --dir "$B" --project "$PROJ2" --key m1 </dev/null)"
S="$(sed -n 's/^backbone: 0 pending message(s) for //p' <<<"$out")"
assert_eq "$(bash "$MOD/scripts/backbone-presence.sh" --dir "$B" me "$PROJ2")" "$S" "me returns the session registered from that project"
assert_eq "$(CLAUDE_PROJECT_DIR="$PROJ2" bash "$MOD/scripts/backbone-presence.sh" --dir "$B" me)" "$S" "...also via CLAUDE_PROJECT_DIR"
CLAUDE_PROJECT_DIR="$PROJ2" "$SEND" --dir "$B" --key m1 </dev/null >/dev/null
rc=0; bash "$MOD/scripts/backbone-presence.sh" --dir "$B" me "$PROJ2" >/dev/null || rc=$?
assert_eq "$rc" "1" "me finds nothing again after the session ends"

# ── SECTIONS-INSERT-BEFORE-SUMMARY ────────────────────────────────────────────

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
