#!/usr/bin/env bash
# Preview scripts/statusline.sh (from this repo, not the installed copy) in your
# terminal: the ctx bar at several percentages, then the aid update glow.
# Uses a throwaway HOME, so nothing under ~/.claude is read or written.
#
# Usage: bash scripts/preview-statusline.sh [glow-seconds]   (default 6)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/statusline.sh"
SECS="${1:-6}"

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.claude/aidev-toolkit"
cat > "$TMP_HOME/.claude/statusline-config.json" <<'EOF'
{"enabled": true, "components": {"dir": true, "branch": true, "ctx": true, "model": true, "effort": false, "vim": false, "aid_version": true}}
EOF
echo "0.101.0" > "$TMP_HOME/.claude/aidev-toolkit/VERSION"
CACHE="$TMP_HOME/.claude/.aid-latest-version"

render() { # pct
  echo "{\"context_window\":{\"used_percentage\":$1},\"cwd\":\"$ROOT\",\"model\":{\"display_name\":\"Sonnet 5.5\"}}" \
    | HOME="$TMP_HOME" bash "$SCRIPT"
}

echo "== ctx bar: 0 → 100% =="
echo "0.101.0" > "$CACHE"   # up to date, so aid: stays plain gray
for pct in 0 4 12 25 37 50 65 80 95 100; do
  printf '%4s%%  ' "$pct"; render "$pct"; echo
done

echo
echo "== aid: up to date (plain gray) =="
render 4; echo

echo
echo "== aid: update available (glow pulses gold each second, ${SECS}s) =="
echo "0.102.1" > "$CACHE"
for (( i = 0; i < SECS; i++ )); do
  printf '\r'; render 4; printf '   '
  sleep 1
done
echo
