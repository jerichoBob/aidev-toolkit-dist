#!/usr/bin/env bash
# Shared helpers for the backbone git-transport scripts. Source this file; do not execute it.

# bb_config_get <dir> <key> — read key=value from <dir>/backbone.config (last wins, CR/space tolerant)
bb_config_get() {
  local f="$1/backbone.config"
  [[ -f "$f" ]] || return 0
  # exact key match (a "." in a per-project key such as notify_confirm.my.app is literal, not a wildcard)
  awk -v k="$2" '
    index($0, "=") { key = substr($0, 1, index($0, "=") - 1); gsub(/^[ \t]+|[ \t\r]+$/, "", key)
      if (key == k) { v = substr($0, index($0, "=") + 1); gsub(/^[ \t]+|[ \t\r]+$/, "", v); r = v; found = 1 } }
    END { if (found) print r }' "$f"
}

# bb_transport <dir> — print effective transport (local|git). Default local. Invalid value is an error.
bb_transport() {
  local v
  v="$(bb_config_get "$1" transport)"
  v="${v:-local}"
  case "$v" in
    local|git) echo "$v" ;;
    *) echo "backbone: invalid transport '$v' in $1/backbone.config (expected local or git)" >&2; return 4 ;;
  esac
}

# bb_fm_get <key> — read a scalar frontmatter value from stdin
bb_fm_get() {
  awk -v k="$1" '
    /^---[ \t\r]*$/ { n++; if (n == 2) exit; next }
    n == 1 && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/[ \t]+#.*$/, "", v); sub(/\r$/, "", v)
      gsub(/^[ \t]+|[ \t]+$/, "", v); gsub(/^"|"$/, "", v)
      print v; exit
    }'
}

# bb_fm_list <key> — read a frontmatter list (inline [a, b] or "- a" block) from stdin, one item per line
bb_fm_list() {
  awk -v k="$1" '
    /^---[ \t\r]*$/ { n++; if (n == 2) exit; next }
    n != 1 { next }
    inlist && /^[ \t]*-[ \t]+/ { v = $0; sub(/^[ \t]*-[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/\r$/, "", v); gsub(/^"|"$/, "", v); print v; next }
    inlist { inlist = 0 }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/[ \t]+#.*$/, "", v); sub(/\r$/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v ~ /^\[/) { gsub(/[\[\]]/, "", v); m = split(v, a, ","); for (i = 1; i <= m; i++) { gsub(/^[ \t"]+|[ \t"]+$/, "", a[i]); if (a[i] != "") print a[i] } }
      else if (v == "") inlist = 1
    }'
}

# bb_safe_name <name> — filesystem-safe form of an agent name. No character Windows rejects
# (: / \ * ? " < > |) survives: ":" becomes "__", the rest become "_". "~" is allowed.
# Names are display data; lookups scan agent_name in the file and never depend on this form.
bb_safe_name() { printf '%s' "$1" | sed -e 's/:/__/g' -e 's#[/\\*?"<>|]#_#g'; }

# bb_address <agent> — the stable address of a session: "x:bob~ab12" -> "x:bob". An address has no suffix.
bb_address() { printf '%s' "${1%%~*}"; }

# bb_presence_files <dir> <agent> — print presence records belonging to <agent>, found by scanning agent_name.
# A session name ("x:bob~ab12") matches its own record and the record named by its address ("x:bob", e.g.
# one made by /backbone-join). An address (no "~") matches its own record and every "<address>~<suffix>" session.
bb_presence_files() {
  local dir="$1" agent="$2" addr f name
  addr="$(bb_address "$agent")"
  for f in "$dir"/presence/presence-*.md; do
    [[ -f "$f" ]] || continue
    name="$(bb_fm_get agent_name < "$f")"
    if [[ "$name" == "$agent" || "$name" == "$addr" || ( "$agent" != *"~"* && "$name" == "$agent~"* ) ]]; then echo "$f"; fi
  done
  return 0
}

# bb_presence_path <dir> <agent> — the path to read or write for <agent>'s own record: the existing
# record whose agent_name is exactly <agent>, else presence/presence-<safe name>.md for a new one.
bb_presence_path() {
  local dir="$1" agent="$2" f
  for f in "$dir"/presence/presence-*.md; do
    [[ -f "$f" ]] || continue
    if [[ "$(bb_fm_get agent_name < "$f")" == "$agent" ]]; then echo "$f"; return 0; fi
  done
  echo "$dir/presence/presence-$(bb_safe_name "$agent").md"
}

# bb_agent_subs <dir> <agent> — print the agent's topic subscriptions (all its sessions' records if <agent> is an address)
bb_agent_subs() {
  local f
  while IFS= read -r f; do
    [[ -n "$f" ]] && bb_fm_list subscriptions < "$f"
  done < <(bb_presence_files "$1" "$2")
  return 0
}

# bb_for_agent <agent> <subs-newline-list> — stdin is a message; exit 0 if it is addressed to the agent
bb_for_agent() {
  local agent="$1" subs="$2" fm routing to topic
  fm="$(cat)"
  routing="$(bb_fm_get routing <<<"$fm")"
  to="$(bb_fm_get to <<<"$fm")"
  topic="$(bb_fm_get topic <<<"$fm")"
  if [[ "$routing" == "direct" && ( "$to" == "$agent" || "$to" == "$(bb_address "$agent")" || "$to" == "any" ) ]]; then return 0; fi
  if [[ "$routing" == "topic" && -n "$topic" ]] && grep -qxF "$topic" <<<"$subs"; then return 0; fi
  return 1
}

# bb_pending_for <dir> <agent> [ref] — print basenames of pending messages addressed to agent.
# With <ref> (e.g. origin/main) read from that git ref instead of the working tree.
bb_pending_for() {
  local dir="$1" agent="$2" ref="${3:-}" subs f name
  subs="$(bb_agent_subs "$dir" "$agent")"
  if [[ -n "$ref" ]]; then
    while IFS= read -r f; do
      name="$(basename "$f")"
      git -C "$dir" show "$ref:$f" 2>/dev/null | bb_for_agent "$agent" "$subs" && echo "$name"
    done < <(git -C "$dir" ls-tree --name-only "$ref" messages/ 2>/dev/null | grep -E -- '-pending\.md$')
  else
    for f in "$dir"/messages/*-pending.md; do
      [[ -f "$f" ]] || continue
      bb_for_agent "$agent" "$subs" < "$f" && basename "$f"
    done
  fi
  return 0
}

# bb_msg_summary <dir> <basename> [ref] — one line: "<type-id> from <from>: <title>"
bb_msg_summary() {
  local dir="$1" name="$2" ref="${3:-}" fm from title base
  if [[ -n "$ref" ]]; then fm="$(git -C "$dir" show "$ref:messages/$name" 2>/dev/null)"; else fm="$(cat "$dir/messages/$name")"; fi
  from="$(bb_fm_get from <<<"$fm")"
  title="$(bb_fm_get title <<<"$fm")"
  base="${name%-pending.md}"
  echo "$base from ${from:-unknown}${title:+: $title}"
}

# bb_resolve_agent <dir> <flag-value> — agent name from flag, BACKBONE_AGENT, or backbone.config agent=
bb_resolve_agent() {
  local a="${2:-${BACKBONE_AGENT:-}}"
  [[ -n "$a" ]] || a="$(bb_config_get "$1" agent)"
  echo "$a"
}

# bb_mark_seen <dir> <message-basename> <agent> — write the receiver's seen marker; prints 1 if newly created
# Marker: messages/seen/<type>-<id>.<agent-safe>  (the sender's ack check looks for it)
bb_mark_seen() {
  local dir="$1" base="${2%-pending.md}" agent="$3" f
  f="$dir/messages/seen/$base.$(bb_safe_name "$agent")"
  [[ -f "$f" ]] && return 0
  mkdir -p "$dir/messages/seen"
  date -u +%Y-%m-%dT%H:%M:%SZ > "$f"
  echo 1
}

# bb_default_dir <script-dir> — $BACKBONE_DIR, else ../agent-backbone from the cwd. The scripts live in the
# aidev-toolkit module, so there is no "the script's repo" to fall back to: with neither, print nothing and
# let the caller report the directory as not found.
bb_default_dir() {
  if [[ -n "${BACKBONE_DIR:-}" ]]; then echo "$BACKBONE_DIR"
  else echo ../agent-backbone; fi
}

# bb_notify_confirm <dir> <agent> — print ask|auto for pings sent as <agent>.
# Order: notify_confirm.<project> (project = agent name before the colon), then notify_confirm, then ask.
# Read only from the machine-local backbone.config. An invalid value is an error (exit 4), not a silent default.
bb_notify_confirm() {
  local dir="$1" project="${2%%:*}" v
  v="$(bb_config_get "$dir" "notify_confirm.$project")"
  [[ -n "$v" ]] || v="$(bb_config_get "$dir" notify_confirm)"
  v="${v:-ask}"
  case "$v" in
    ask|auto) echo "$v" ;;
    *) echo "backbone: invalid notify_confirm '$v' in $dir/backbone.config (expected ask or auto)" >&2; return 4 ;;
  esac
}

# bb_now — current UTC time, ISO 8601
bb_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# bb_fm_set <file> <key> <value> — set a scalar frontmatter key, replacing it if present, else adding it
# as the last frontmatter line. Writes through a temp file, so it behaves the same on macOS and GNU.
bb_fm_set() {
  local f="$1" k="$2" v="$3" tmp
  tmp="$(mktemp "${f}.XXXXXX")" || return 1
  awk -v k="$k" -v v="$v" '
    /^---[ \t\r]*$/ { n++; if (n == 2 && !done) { print k ": " v; done = 1 } print; next }
    n == 1 && index($0, k ":") == 1 { print k ": " v; done = 1; next }
    { print }' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# bb_slug <text> — lowercase, runs of non-alphanumerics become "-", trimmed
bb_slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//'; }

# bb_random_suffix — 4 random lowercase letters/digits (random, not a counter: two machines never collide before they sync)
bb_random_suffix() { LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 4; }

# bb_session_file <dir> <key> — machine-local file remembering which session name a Claude session registered as
bb_session_file() { printf '%s/.claude/data/backbone/sessions/%s' "$1" "$(printf '%s' "$2" | tr -c 'A-Za-z0-9_-' '_')"; }
