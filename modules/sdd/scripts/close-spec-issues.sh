#!/usr/bin/env bash
# close-spec-issues.sh — close the GitHub issue a finished spec came from (spec v140).
# The ONE implementation behind the issue-close step of /sdd-code and /commit-push: do not re-derive it inline.
#
# Modes:
#   (default)  list   Read-only, offline. For each spec whose frontmatter has github_issue and github_issue_repo,
#                     prints "<version>\t<repo>\t#<n>\teligible" or "<version>\t<repo>\t#<n>\tskipped:<reason>",
#                     then "count=N" (eligible only). Specs with no linked issue are not printed. Exit 0.
#   --apply           For each eligible spec: check the issue is still open (gh), close it with a comment naming
#                     the project VERSION, check off the "Close GitHub issue #N" task in specs/README.md, and
#                     append an audit line. Exit non-zero if any close failed.
#
# Guards (first failing one is the reason; the issue then stays open):
#   not-complete (README status is not Complete and frontmatter status is not complete), bad-issue, bad-repo, already-done (task already checked: nothing to do), unchecked-tasks
#   (any other unchecked README task, including manual verification), uncommitted (tracked changes present),
#   not-pushed (HEAD not contained in the upstream branch), gh-unavailable, already-closed (task checked off, no comment).
# Idempotent: a second run on the same state changes nothing (no comment, no second audit line, no README edit).
#
# Root: the git root of the current directory. Env: ROOT overrides it (tests); SPECS_PARSE overrides the parser;
#       AUDIT_FILE overrides ~/.config/aidev/close-issues-audit.log.
set -euo pipefail

log() { echo "close-spec-issues step=$1 outcome=$2 ${3:-}" >&2; }

MODE=list
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "Usage: $0 [--apply]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "Usage: $0 [--apply]" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE="${SPECS_PARSE:-$HERE/specs-parse.sh}"
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AUDIT_FILE="${AUDIT_FILE:-$HOME/.config/aidev/close-issues-audit.log}"
cd "$ROOT" || { log root fail "root=$ROOT"; exit 1; }

[[ -f specs/README.md ]] || { log readme fail "detail=specs/README.md not found under $ROOT"; exit 1; }
[[ -x "$PARSE" ]] || { log parse fail "detail=not executable: $PARSE"; exit 1; }
status_out=$("$PARSE" status) || { log status fail "detail=specs-parse.sh status failed"; exit 1; }

# Tree-wide guards, evaluated once so closing one spec cannot make the next look dirty.
tree_reason=""
if [[ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
  tree_reason="uncommitted"
elif ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || ! git merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
  tree_reason="not-pushed"
fi

fm() { # fm <file> <key>: frontmatter value, quotes and trailing comment stripped
  awk -v k="$2" '
    NR==1 && $0!="---" {exit}
    NR>1 && $0=="---" {exit}
    index($0,k":")==1 { v=substr($0,length(k)+2); sub(/[ \t]+#.*$/,"",v); gsub(/^[ \t"\047]+|[ \t"\047]+$/,"",v); print v; exit }
  ' "$1"
}

section_unchecked() { # section_unchecked <vN>: unchecked task lines of that README section
  awk -v h="## $1:" 'index($0,h)==1{f=1;next} f&&/^## /{exit} f&&/^- \[ \]/{print}' specs/README.md
}

check_off() { # check_off <vN> <issue>
  python3 -I - "$1" "$2" <<'PY'
import re, sys
ver, num = sys.argv[1], sys.argv[2]
lines = open('specs/README.md', encoding='utf-8').read().split('\n')
inside = False
for i, l in enumerate(lines):
    if l.startswith('## %s:' % ver):
        inside = True; continue
    if inside and l.startswith('## '):
        break
    if inside and re.match(r'^- \[ \] Close GitHub issue #%s\b' % re.escape(num), l):
        lines[i] = l.replace('- [ ]', '- [x]', 1)
open('specs/README.md', 'w', encoding='utf-8').write('\n'.join(lines))
PY
}

audit() { # audit <action> <resource> <outcome>
  mkdir -p "$(dirname "$AUDIT_FILE")"
  printf '%s actor=%s action=%s resource=%s outcome=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${USER:-unknown}" "$1" "$2" "$3" >> "$AUDIT_FILE"
}

project_version=""
[[ -f VERSION ]] && project_version="$(tr -d '[:space:]' < VERSION)"

eligible=0
failed=0
for f in specs/spec-v*.md specs/completed/spec-v*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  [[ "$base" =~ ^spec-(v[0-9]+(\.[0-9]+)?)- ]] || continue
  ver="${BASH_REMATCH[1]}"
  num="$(fm "$f" github_issue)"
  repo="$(fm "$f" github_issue_repo)"
  [[ -n "$num" && -n "$repo" && "$num" != "null" && "$repo" != "null" && "$num" != "~" ]] || continue   # no linked issue: nothing to do, not an error

  reason=""
  status=$(printf '%s\n' "$status_out" | awk -F'\t' -v v="$ver" '$1==v {print $5; exit}')
  unchecked=$(section_unchecked "$ver")
  fmstatus="$(fm "$f" status)"
  # specs-parse derives status from the checkboxes, so a spec whose own "Close GitHub issue" task is still open reads
  # In Progress. /sdd-code sets frontmatter `status: complete` when it finishes; trust that plus the unchecked-task guard.
  if [[ "$status" != "Complete" && "$fmstatus" != "complete" ]]; then reason="not-complete"
  elif [[ ! "$num" =~ ^[0-9]+$ ]]; then reason="bad-issue"
  elif [[ ! "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then reason="bad-repo"
  elif ! grep -qE "^- \[ \] Close GitHub issue #${num}\b" <<<"$unchecked"; then reason="already-done"
  elif [[ -n "$(grep -vE "^- \[ \] Close GitHub issue #${num}\b" <<<"$unchecked" || true)" ]]; then reason="unchecked-tasks"
  elif [[ -n "$tree_reason" ]]; then reason="$tree_reason"
  fi

  if [[ -n "$reason" ]]; then
    printf '%s\t%s\t#%s\tskipped:%s\n' "$ver" "$repo" "$num" "$reason"
    continue
  fi

  if [[ "$MODE" == "list" ]]; then
    printf '%s\t%s\t#%s\teligible\n' "$ver" "$repo" "$num"; eligible=$((eligible+1)); continue
  fi

  # --apply: live checks and the close itself.
  resource="$repo#$num"
  if ! command -v gh >/dev/null 2>&1; then
    printf '%s\t%s\t#%s\tskipped:gh-unavailable\n' "$ver" "$repo" "$num"; continue
  fi
  if ! state=$(gh issue view "$num" --repo "$repo" --json state --jq .state 2>/dev/null); then
    printf '%s\t%s\t#%s\tskipped:gh-unavailable\n' "$ver" "$repo" "$num"; continue
  fi
  if [[ "$state" == "CLOSED" ]]; then
    check_off "$ver" "$num"
    printf '%s\t%s\t#%s\tskipped:already-closed\n' "$ver" "$repo" "$num"; continue
  fi
  comment="Fixed by spec $ver${project_version:+ in v$project_version} and verified: all of its tasks are complete and the change is pushed."
  if gh issue close "$num" --repo "$repo" --comment "$comment" >/dev/null 2>&1; then
    check_off "$ver" "$num"
    audit close "$resource" success
    printf '%s\t%s\t#%s\tclosed\n' "$ver" "$repo" "$num"; eligible=$((eligible+1))
  else
    audit close "$resource" failure
    log close fail "resource=$resource"
    printf '%s\t%s\t#%s\tfailed:close\n' "$ver" "$repo" "$num"; failed=$((failed+1))
  fi
done

echo "count=$eligible"
[[ $failed -eq 0 ]]
