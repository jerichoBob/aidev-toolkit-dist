#!/usr/bin/env bash
# archive-complete-specs.sh — archive Complete specs: specs/spec-v*.md -> specs/completed/.
# This is the ONE implementation behind /sdd-specs-archive: do not re-derive it inline.
#
# Modes:
#   (default)  list   Read-only. Prints "<version>\t<name>\t<path>" per spec to archive,
#                     then "count=N". Exit 0 even when N=0.
#   --apply           mkdir specs/completed, one `git mv` for all files, then rewrite and
#                     verify markdown links (fix-spec-links.sh). Exit non-zero if any spec
#                     link is unresolved after the rewrite.
#
# "Complete" comes from `specs-parse.sh status` (no second README parser here). A spec file
# whose version has no section in specs/README.md is never moved. Layer-suffix siblings
# (spec-v68-...-api.md -> v68-api) use the suffix list owned by specs-parse.sh.
#
# Root: the git root of the current directory (not where this script is installed).
# Env:  ROOT overrides the root (tests); SPECS_PARSE / FIX_SPEC_LINKS override sibling scripts.
set -euo pipefail

log() { echo "archive-complete-specs step=$1 outcome=$2 ${3:-}" >&2; }

MODE=list
case "${1:-}" in
  "") ;;
  --apply) MODE=apply ;;
  *) echo "Usage: $0 [--apply]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "Usage: $0 [--apply]" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE="${SPECS_PARSE:-$HERE/specs-parse.sh}"
FIXER="${FIX_SPEC_LINKS:-$HERE/fix-spec-links.sh}"
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || { log root fail "root=$ROOT"; exit 1; }

[[ -f specs/README.md ]] || { log readme fail "detail=specs/README.md not found under $ROOT"; exit 1; }
[[ -x "$PARSE" ]] || { log parse fail "detail=not executable: $PARSE"; exit 1; }
status_out=$("$PARSE" status) || { log status fail "detail=specs-parse.sh status failed"; exit 1; }
suffixes=$(grep -m1 '^LAYER_SUFFIXES=' "$PARSE" | sed -E 's/^LAYER_SUFFIXES="(.*)".*/\1/' || true)

rows=()
files=()
for f in specs/spec-v*.md; do
  [[ -e "$f" ]] || continue
  base=$(basename "$f")
  [[ "$base" =~ ^spec-(v[0-9]+(\.[0-9]+)?)- ]] || continue
  ver="${BASH_REMATCH[1]}"
  if [[ -n "$suffixes" && "$base" =~ -(${suffixes})\.md$ ]]; then ver="${ver}-${BASH_REMATCH[1]}"; fi
  line=$(printf '%s\n' "$status_out" | awk -F'\t' -v v="$ver" '$1==v && $5=="Complete" {print $1 "\t" $2; exit}')
  [[ -n "$line" ]] || continue
  rows+=("$(printf '%s\t%s' "$line" "$f")")
  files+=("$f")
done

for r in "${rows[@]+"${rows[@]}"}"; do printf '%s\n' "$r"; done
echo "count=${#files[@]}"

[[ "$MODE" == "apply" ]] || exit 0
[[ ${#files[@]} -gt 0 ]] || { echo "Nothing to archive."; exit 0; }

mkdir -p specs/completed
git mv "${files[@]}" specs/completed/ || { log move fail "detail=git mv failed"; exit 1; }
echo "moved=${#files[@]}"

# Rewrite links to the moved specs, then verify nothing is left unresolved.
moved=()
for f in "${files[@]}"; do moved+=("specs/completed/$(basename "$f")"); done
"$FIXER" --root "$ROOT" fix "${moved[@]}"
"$FIXER" --root "$ROOT" verify
