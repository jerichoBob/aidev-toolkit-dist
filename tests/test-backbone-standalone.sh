#!/usr/bin/env bash
# The backbone module stands alone (v6): no sibling repo, state directory resolved per machine, created by
# backbone-init.sh, and two machines (two HOMEs) exchange a message through a shared git remote with no --dir.
# Real git, real scripts, no mocks. Run from the aidev-toolkit root: bash tests/test-backbone-standalone.sh
set -uo pipefail
exec </dev/null   # hooks read stdin; do not eat the script list run-all.sh pipes in
MOD="$(cd "$(dirname "$0")/../modules/backbone" && pwd)"
S="$MOD/scripts"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
pass() { echo "  PASS  $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
eq() { [[ "$1" == "$2" ]] && pass "$3" || fail "$3 (expected '$2', got '$1')"; }
has() { grep -q -- "$2" "$1" 2>/dev/null && pass "$3" || fail "$3 (no '$2' in $1)"; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_AUTHOR_NAME=T GIT_COMMITTER_NAME=T GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_EMAIL=t@e
unset BACKBONE_DIR BACKBONE_AGENT XDG_CONFIG_HOME

echo ""; echo "Backbone Standalone Tests"; echo "========================="

echo ""; echo "1. State directory resolution"
H="$TMP/h1"; mkdir -p "$H"
eq "$(HOME="$H" bash "$S/backbone-dir.sh")" "$H/.config/aidev-backbone/bus" "default is <config home>/bus"
mkdir -p "$H/.config/aidev-backbone"; echo "$H/elsewhere" > "$H/.config/aidev-backbone/dir"
eq "$(HOME="$H" bash "$S/backbone-dir.sh")" "$H/elsewhere" "the pointer file wins over the default"
printf '~/viatilde\n' > "$H/.config/aidev-backbone/dir"
eq "$(HOME="$H" bash "$S/backbone-dir.sh")" "$H/viatilde" "a ~ in the pointer file expands"
eq "$(HOME="$H" BACKBONE_DIR=/tmp/explicit bash "$S/backbone-dir.sh")" "/tmp/explicit" "BACKBONE_DIR wins over the pointer file"
eq "$(HOME="$H" XDG_CONFIG_HOME="$H/xdg" bash "$S/backbone-dir.sh")" "$H/xdg/aidev-backbone/bus" "XDG_CONFIG_HOME is honored"
HOME="$H" bash "$S/backbone-dir.sh" --check >/dev/null 2>"$TMP/err"; rc=$?
eq "$rc" "1" "--check fails when the directory is not set up"
has "$TMP/err" "run /backbone-setup" "...and says what to do"
if grep -rn '\.\./agent-backbone' "$MOD/skills" "$MOD/scripts" "$MOD/templates" >/dev/null; then fail "module still names the sibling ../agent-backbone"; else pass "module names no sibling ../agent-backbone path"; fi

echo ""; echo "2. backbone-init.sh (local)"
H="$TMP/h2"; mkdir -p "$H"
out="$(HOME="$H" bash "$S/backbone-init.sh" 2>&1)"; rc=$?
eq "$rc" "0" "init succeeds with no arguments"
D="$H/.config/aidev-backbone/bus"
for p in messages/archive presence roster.md backbone.config .gitignore; do [[ -e "$D/$p" ]] && pass "created $p" || fail "missing $p"; done
has "$D/backbone.config" "^transport=local" "local by default"
has "$D/.gitignore" "^backbone.config" "per-machine config is ignored"
HOME="$H" bash "$S/backbone-dir.sh" --check >/dev/null 2>&1 && pass "--check passes after init" || fail "--check fails after init"
echo "mine" > "$D/roster.md"; HOME="$H" bash "$S/backbone-init.sh" >/dev/null 2>&1
eq "$(cat "$D/roster.md")" "mine" "a second run keeps an edited roster"
eq "$(grep -c '^backbone.config' "$D/.gitignore")" "1" "...and does not duplicate .gitignore lines"

echo ""; echo "3. Import from an older checkout"
OLD="$TMP/old"; mkdir -p "$OLD/messages/archive" "$OLD/messages/types" "$OLD/presence"
echo "---" > "$OLD/messages/cr-1-completed.md"; echo x > "$OLD/messages/archive/a.md"; echo x > "$OLD/messages/types/cr.md"
printf -- '---\nagent_name: "x:main"\n---\n' > "$OLD/presence/presence-x:main.md"; echo x > "$OLD/presence/presence-example.md"
printf '| agent | human | notify |\n| --- | --- | --- |\n| x:* | Z | t |\n' > "$OLD/roster.md"
H="$TMP/h3"; mkdir -p "$H"; out="$(HOME="$H" bash "$S/backbone-init.sh" --import "$OLD" 2>&1)"; D="$H/.config/aidev-backbone/bus"
[[ -f "$D/messages/cr-1-completed.md" && -f "$D/messages/archive/a.md" ]] && pass "messages and archive imported" || fail "messages not imported: $out"
[[ -f "$D/presence/presence-x__main.md" && ! -e "$D/presence/presence-x:main.md" ]] && pass "presence imported with a Windows-safe name" || fail "presence name not migrated"
[[ ! -e "$D/presence/presence-example.md" && ! -e "$D/messages/types/cr.md" ]] && pass "example record and type schemas are not imported" || fail "imported something it should not"
has "$D/roster.md" "Z" "roster imported over the untouched template"
HOME="$H" bash "$S/backbone-init.sh" --import "$OLD" >/dev/null 2>&1; eq "$(ls "$D/presence" | grep -c main)" "1" "a second import adds no duplicates"
HOME="$H" bash "$S/backbone-init.sh" --import "$TMP/nope" >/dev/null 2>&1; eq "$?" "4" "a missing --import directory is a usage error"

echo ""; echo "4. Two machines through a shared remote, no sibling repo, no --dir"
git init -q --bare -b main "$TMP/remote.git"
seed="$TMP/seed"; git clone -q "$TMP/remote.git" "$seed" 2>/dev/null; touch "$seed/.keep"; git -C "$seed" add -A; git -C "$seed" commit -q -m init; git -C "$seed" push -q origin HEAD:main
for who in bob nate; do
  mkdir -p "$TMP/$who-home/proj"; git -C "$TMP/$who-home/proj" init -q -b main; git -C "$TMP/$who-home/proj" config user.name "$who"
  HOME="$TMP/$who-home" bash "$S/backbone-init.sh" --remote "$TMP/remote.git" >/dev/null 2>&1; rc=$?
  eq "$rc" "0" "$who: init --remote clones the shared backbone"
  has "$TMP/$who-home/.config/aidev-backbone/bus/backbone.config" "^transport=git" "$who: transport=git"
done
BH="$TMP/bob-home"; NH="$TMP/nate-home"; BD="$BH/.config/aidev-backbone/bus"; ND="$NH/.config/aidev-backbone/bus"
HOME="$BH" bash "$S/backbone-init.sh" --remote "$TMP/remote.git" >/dev/null 2>&1; eq "$?" "5" "init --remote refuses to clone over an existing checkout"
echo "agent=demo:bob" >> "$BD/backbone.config"; echo "agent=demo:nate" >> "$ND/backbone.config"
HOME="$BH" CLAUDE_PROJECT_DIR="$BH/proj" bash "$S/backbone-session-start.sh" >/dev/null 2>&1
HOME="$NH" CLAUDE_PROJECT_DIR="$NH/proj" bash "$S/backbone-session-start.sh" >/dev/null 2>&1
cat > "$BD/messages/task-1-pending.md" <<M
---
id: "1"
type: task
status: pending
routing: direct
from: demo:bob
to: demo:nate
title: Ping across machines
created: 2026-10-08
updated: 2026-10-08
---

Body.
M
HOME="$BH" bash "$S/backbone-sync.sh" push publish task-1 >/dev/null 2>&1; eq "$?" "0" "bob publishes with no --dir"
out="$(HOME="$NH" CLAUDE_PROJECT_DIR="$NH/proj" bash "$S/backbone-session-start.sh" 2>&1 | head -1)"
case "$out" in "backbone: 1 pending message(s) for demo:nate~"*) pass "nate's hook reports 1 pending first, with no --dir";; *) fail "nate's first line: $out";; esac
[[ -f "$ND/messages/task-1-pending.md" ]] && pass "the message reached nate's own directory" || fail "message did not arrive"
[[ ! -e "$TMP/agent-backbone" && ! -e "$TMP/bob-home/agent-backbone" ]] && pass "no sibling agent-backbone exists anywhere" || fail "a sibling appeared"

echo ""; echo "5. Hooks and bundled content need no sibling"
P="$TMP/hookproj"; mkdir -p "$P"; bash "$S/backbone-install-hooks.sh" "$P" --yes >/dev/null 2>&1
has "$P/.claude/settings.json" "backbone-session-start.sh\"" "installed hook command has no --dir"
if grep -q -- '--dir' "$P/.claude/settings.json"; then fail "hook pins a directory"; else pass "hooks pin no directory"; fi
bash "$S/backbone-install-hooks.sh" "$TMP/hookproj2" --yes >/dev/null 2>&1
mkdir -p "$TMP/hp3"; bash "$S/backbone-install-hooks.sh" "$TMP/hp3" --backbone-dir /srv/bb --yes >/dev/null 2>&1; has "$TMP/hp3/.claude/settings.json" "start.sh --dir /srv/bb" "--backbone-dir still pins one when asked"
for f in docs/notify.md docs/git-transport.md docs/CONVENTIONS.md types/cr.md types/task.md; do [[ -s "$MOD/$f" ]] && pass "bundled $f" || fail "missing bundled $f"; done
for f in "$MOD"/docs/*.md; do grep -q 'agent-backbone/' "$f" && fail "$(basename "$f") still points at an agent-backbone path" || pass "$(basename "$f") points at no agent-backbone path"; done

echo ""; echo "═══════════════════════"; echo "  Passed: $PASS"; echo "  Failed: $FAIL"; echo "═══════════════════════"; echo ""
[[ $FAIL -eq 0 ]]
