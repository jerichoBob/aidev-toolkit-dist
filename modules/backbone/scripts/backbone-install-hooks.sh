#!/usr/bin/env bash
# Add the backbone SessionStart and SessionEnd hooks to a project's .claude/settings.json.
#
# Non-destructive: existing settings and hooks are kept, an identical hook is never added twice, and
# the previous file is saved as settings.json.bak-backbone before anything is written. Consent is
# required: you are asked first, and with no terminal nothing is changed unless --yes is passed.
# Settings that are not valid JSON are never touched.
#
# Usage: backbone-install-hooks.sh <project-dir> [--backbone-dir REL] [--scripts-dir PATH] [--yes] [--dry-run]
#   --backbone-dir  where the backbone is, relative to the project (default ../agent-backbone)
#   --scripts-dir   where the hook scripts are (default ~/.claude/aidev-toolkit/modules/backbone/scripts, the
#                   installed module; written as ~ so the same settings.json works on every machine)
#   --dry-run       show the hooks that would be added and change nothing
# Needs jq, or python3 as a fallback. With neither, it prints the snippet to paste by hand.
# Exit: 0 installed / already installed / dry run · 3 no jq or python3 (snippet printed) · 4 usage or
#       invalid settings · 5 consent not given
set -uo pipefail

PROJECT=""; BB="../agent-backbone"; YES=0; DRY=0
SCRIPTS_REF="~/.claude/aidev-toolkit/modules/backbone/scripts"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backbone-dir) BB="${2:-}"; shift 2 ;;
    --scripts-dir) SCRIPTS_REF="${2:-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -*) echo "backbone-install-hooks: unknown argument $1" >&2; exit 4 ;;
    *) PROJECT="$1"; shift ;;
  esac
done
[[ -n "$PROJECT" && -d "$PROJECT" ]] || { echo "usage: backbone-install-hooks.sh <project-dir> [--backbone-dir REL] [--scripts-dir PATH] [--yes] [--dry-run]" >&2; exit 4; }
PROJECT="$(cd "$PROJECT" && pwd)"
SETTINGS="$PROJECT/.claude/settings.json"

START="bash $SCRIPTS_REF/backbone-session-start.sh --dir $BB"
END="bash $SCRIPTS_REF/backbone-session-end.sh --dir $BB"

snippet() {
  cat <<JSON
{
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "$START" } ] } ],
    "SessionEnd":   [ { "hooks": [ { "type": "command", "command": "$END" } ] } ]
  }
}
JSON
}

if [[ -f "$SETTINGS" ]]; then
  if command -v jq >/dev/null 2>&1; then jq -e . "$SETTINGS" >/dev/null 2>&1 || { echo "backbone-install-hooks: $SETTINGS is not valid JSON; not touching it" >&2; exit 4; }
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SETTINGS" 2>/dev/null || { echo "backbone-install-hooks: $SETTINGS is not valid JSON; not touching it" >&2; exit 4; }
  fi
fi

if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "backbone-install-hooks: neither jq nor python3 is available to merge JSON safely."
  echo "Add this to $SETTINGS by hand (merge it into any existing \"hooks\" object):"
  snippet
  exit 3
fi

# merge <event> <command> — print the settings JSON with the hook added once
merge() {
  local file="$1" ev="$2" cmd="$3"
  if command -v jq >/dev/null 2>&1; then
    jq --arg ev "$ev" --arg cmd "$cmd" '
      .hooks //= {} | .hooks[$ev] //= [] |
      if any(.hooks[$ev][]?; any(.hooks[]?; .command == $cmd)) then .
      else .hooks[$ev] += [{"hooks": [{"type": "command", "command": $cmd}]}] end' "$file"
  else
    python3 - "$file" "$ev" "$cmd" <<'PY'
import json, sys
f, ev, cmd = sys.argv[1:4]
d = json.load(open(f))
lst = d.setdefault("hooks", {}).setdefault(ev, [])
if not any(h.get("command") == cmd for e in lst for h in e.get("hooks", [])):
    lst.append({"hooks": [{"type": "command", "command": cmd}]})
print(json.dumps(d, indent=2))
PY
  fi
}

work="$(mktemp)"; trap 'rm -f "$work" "$work.2"' EXIT
if [[ -f "$SETTINGS" ]]; then cp "$SETTINGS" "$work"; else echo '{}' > "$work"; fi
merge "$work" SessionStart "$START" > "$work.2" && merge "$work.2" SessionEnd "$END" > "$work" || { echo "backbone-install-hooks: merge failed; nothing changed" >&2; exit 4; }

# norm <file> — canonical JSON, so formatting differences do not count as changes
norm() {
  if command -v jq >/dev/null 2>&1; then jq -S . "$1"
  else python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])), sort_keys=True, indent=2))' "$1"; fi
}
if [[ -f "$SETTINGS" && "$(norm "$work")" == "$(norm "$SETTINGS")" ]]; then
  echo "backbone hooks already installed in $SETTINGS"; exit 0
fi

echo "This will add to $SETTINGS:"
echo "  SessionStart: $START"
echo "  SessionEnd:   $END"
[[ -f "$SETTINGS" ]] && echo "  (existing settings are kept; the current file is saved as settings.json.bak-backbone)"
[[ $DRY -eq 1 ]] && { echo "dry run: nothing changed"; exit 0; }

if [[ $YES -ne 1 ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Install these hooks? [y/N] " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "not installed"; exit 5; }
  else
    echo "consent required: re-run with --yes to install (no terminal to ask on)" >&2
    exit 5
  fi
fi

mkdir -p "$PROJECT/.claude"
[[ -f "$SETTINGS" ]] && cp "$SETTINGS" "$SETTINGS.bak-backbone"
cp "$work" "$SETTINGS"
echo "installed backbone hooks in $SETTINGS"
