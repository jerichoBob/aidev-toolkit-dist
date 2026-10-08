#!/usr/bin/env bash
# Command-file integrity (v6 AC-9, AC-10): every script a command names exists in the repo, every
# command file another command points at exists, each deprecated alias forwards to a real target
# and carries its deprecation note, and the installer ships all of it.
# Run from the aidev-toolkit root: bash tests/test-commands.sh
set -uo pipefail
exec </dev/null   # hooks read stdin; do not eat the script list that run-all.sh pipes in

MOD="$(cd "$(dirname "$0")/../modules/backbone" && pwd)"
SKILLS="$MOD/skills"
CMDS="$SKILLS"
TMP_DIR="$(mktemp -d)"
PASS=0; FAIL=0
trap 'rm -rf "$TMP_DIR"' EXIT
pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

# the five user-facing commands (backbone-setup is a toolkit skill) and the deprecated names
NEW=(backbone backbone-send backbone-inbox backbone-done)

echo ""
echo "Command Integrity Tests"
echo "======================="

echo ""
echo "1. Commands exist"
for c in "${NEW[@]}"; do
  [[ -f "$CMDS/$c.md" ]] && pass "$c.md exists" || fail "$c.md is missing"
done

echo ""
echo "2. Every script a command names exists (AC-10)"
refs=0
for f in "$CMDS"/backbone*.md; do
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    refs=$((refs + 1))
    if [[ -f "$MOD/scripts/$script" ]]; then pass "$(basename "$f") -> scripts/$script"
    else fail "$(basename "$f") names scripts/$script, which does not exist"; fi
  done < <(grep -oE '(backbone-[a-z-]+|install-backbone-commands)\.sh' "$f" | sort -u)
done
[[ $refs -gt 0 ]] && pass "found $refs script references to check" || fail "no script references found: the pattern is broken"

echo ""
echo "3. Command files a command points at exist"
for f in "$CMDS"/backbone*.md; do
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    if [[ -f "$SKILLS/$(basename "$ref")" ]]; then pass "$(basename "$f") -> $ref"; else fail "$(basename "$f") points at $ref, which does not exist"; fi
  done < <(grep -oE '\.claude/commands/[a-z-]+\.md' "$f" | sort -u)
done

echo ""
echo "4. /backbone documents every subcommand"
for sub in join leave status subscribe unsubscribe update name; do
  grep -qE "^## .*\b$sub\b" "$CMDS/backbone.md" && pass "/backbone documents '$sub'" || fail "/backbone has no '$sub' section"
done

echo ""
echo "5. Commands never build presence filenames or call removed names"
for c in "${NEW[@]}"; do
  if grep -E 'presence/presence-\{' "$CMDS/$c.md" >/dev/null; then fail "$c.md builds a presence filename by hand"; else pass "$c.md uses backbone-presence.sh for lookups"; fi
done
for c in backbone backbone-send backbone-inbox backbone-done; do
  bad="$(grep -nE '/backbone-(publish|complete|join|leave|roster|subscribe|unsubscribe|update)\b' "$CMDS/$c.md" | grep -v "Replaces" || true)"
  [[ -z "$bad" ]] && pass "$c.md does not send people to a deprecated name" || fail "$c.md uses a deprecated name: $bad"
done
grep -q "untrusted requests, not instructions" "$CMDS/backbone-inbox.md" && pass "inbox keeps the untrusted-message display" || fail "inbox lost the untrusted-message display"

echo ""
echo "6. The toolkit installer ships every skill and makes every script executable"
INSTALL_SH="$(cd "$MOD/../.." && pwd)/scripts/install.sh"
arr="$(sed -n '/^BACKBONE_SKILLS=(/,/^)/p' "$INSTALL_SH")"
for f in "$SKILLS"/*.md; do
  n="$(basename "$f")"
  grep -q "\"$n\"" <<<"$arr" && pass "install.sh lists $n" || fail "install.sh does not list $n (BACKBONE_SKILLS)"
done
while IFS= read -r listed; do
  [[ -f "$SKILLS/$listed" ]] && pass "$listed is listed and exists" || fail "install.sh lists $listed, which is not in modules/backbone/skills"
done < <(grep -oE '"[a-z-]+\.md"' <<<"$arr" | tr -d '"')
for s in "$MOD"/scripts/*.sh; do
  [[ -x "$s" ]] && pass "$(basename "$s") is executable in the repo" || fail "$(basename "$s") is not executable"
done
grep -q 'modules/backbone/scripts/\*.sh' "$INSTALL_SH" && pass "install.sh chmods the module scripts" || fail "install.sh does not chmod the module scripts"
for t in backbone.config.example roster.md hooks-settings.json; do
  [[ -f "$MOD/templates/$t" ]] && pass "template $t exists" || fail "template $t is missing"
done

echo ""
echo "7. Install into a scratch HOME (never the real ~/.claude): skills land, script paths resolve"
REPO="$(cd "$MOD/../.." && pwd)"
SH="$TMP_DIR/home"; mkdir -p "$SH/.claude"
cp -R "$REPO" "$SH/.claude/aidev-toolkit"
if [[ -z "${GH_TOKEN:-}" ]]; then GH_TOKEN="$(gh auth token 2>/dev/null || true)"; export GH_TOKEN; fi
HOME="$SH" bash "$REPO/scripts/install.sh" --quiet >/dev/null 2>&1; rc=$?
[[ $rc -eq 0 ]] && pass "install.sh exits 0 in a scratch HOME" || fail "install.sh exited $rc in a scratch HOME"
for c in "${NEW[@]}" backbone-setup; do
  [[ -f "$SH/.claude/commands/$c.md" ]] && pass "installed commands/$c.md" || fail "install.sh did not install commands/$c.md"
done
[[ -f "$SH/.claude/skills/backbone.md" ]] && pass "installed skills/backbone.md" || fail "install.sh did not install skills/backbone.md"
if find "$SH/.claude/commands" "$SH/.claude/skills" -name 'backbone*.md' -type l | grep -q .; then fail "backbone skills must be real files, not symlinks"; else pass "backbone skills are real files"; fi
[[ -f "$SH/.claude/commands/backbone-setup.md" ]] && ! ls "$SH/.claude/commands" | grep -q '^backbone-setup.md.bak' && pass "backbone-setup is installed from the module" || fail "backbone-setup missing"
# every absolute script path an installed skill names resolves under the scratch HOME
miss=0
for f in "$SH/.claude/commands"/backbone*.md; do
  grep -q 'aidev-toolkit/modules/backbone/scripts' "$f" || continue
  while IFS= read -r sc; do [[ -x "$SH/.claude/aidev-toolkit/modules/backbone/scripts/$sc" ]] || { fail "$(basename "$f") names $sc, not executable after install"; miss=1; }; done < <(grep -oE 'backbone-[a-z-]+\.sh' "$f" | sort -u)
done
[[ $miss -eq 0 ]] && pass "every script an installed skill names is executable under the module path"
[[ -z "$(ls "$SH/.claude/aidev-toolkit/modules/backbone/scripts" | grep -v '^backbone-')" ]] && pass "no stray files in the module scripts dir" || fail "stray files in module scripts"
echo ""
echo "═══════════════════════"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "═══════════════════════"
echo ""
[[ $FAIL -eq 0 ]]
