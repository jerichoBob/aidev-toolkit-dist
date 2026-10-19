#!/bin/bash
#
# aid-changelog.sh — print a readable changelog of what changed since a version.
#
# Usage: aid-changelog.sh <old_version> [readme_path] [max_versions]
#
# Reads the "#### vX.Y.Z (YYYY-MM-DD)" release-note entries from the toolkit
# README and prints every release newer than <old_version>, newest first:
#
#   2026-10-19  v0.105.4
#     - fix: sdd-code checks task boxes immediately ...
#
# Commit hashes, author suffixes, and version-bump/publish bookkeeping lines
# are dropped so only the substance of each change remains.

OLD="${1:-}"
README="${2:-$HOME/.claude/aidev-toolkit/README.md}"
MAX="${3:-10}"

[ -z "$OLD" ] && { echo "usage: $0 <old_version> [readme_path] [max_versions]" >&2; exit 2; }
[ -f "$README" ] || { echo "README not found: $README" >&2; exit 1; }

awk -v old="$OLD" -v max="$MAX" '
function newer(a, b,   x, y, i) {
  split(a, x, "."); split(b, y, ".")
  for (i = 1; i <= 3; i++) {
    if ((x[i] + 0) > (y[i] + 0)) return 1
    if ((x[i] + 0) < (y[i] + 0)) return 0
  }
  return 0
}
/^#### v[0-9]/ {
  ver = $2; sub(/^v/, "", ver)
  date = $3; gsub(/[()]/, "", date)
  show = newer(ver, old)
  if (show) {
    if (shown >= max) { hidden++; show = 0; next }
    shown++
    printf "%s%s  v%s\n", (shown > 1 ? "\n" : ""), date, ver
  }
  next
}
/^(#|---)/ && !/^####/ { if (show) show = 0; next }
show && /^- / {
  line = $0
  sub(/ *\[`[0-9a-f]+`\]$/, "", line)
  if (line ~ /^- (chore|build|ci)(\([^)]*\))?: (bump version|publish)/) next
  print "  " line
}
END { if (hidden) printf "\n...and %d older release(s) not shown\n", hidden }
' "$README"
