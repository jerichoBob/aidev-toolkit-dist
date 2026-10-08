#!/usr/bin/env bash
# Refuse to publish a message whose body looks like it contains a secret.
# Prints one "line N: <what matched>" per finding — never the matched text itself.
#
# Usage: backbone-secret-check.sh <file>
# Exit: 0 clean · 1 possible secret found · 4 usage
#
# Patterns: credentials inside a connection string (scheme://user:pass@host), Bearer tokens,
# PEM private keys, AWS access key ids, GitHub/Slack/API-key prefixes, and long mixed-case
# base64-looking tokens. Obvious placeholders (<password>, ${PASSWORD}, ****) are allowed.
set -uo pipefail

FILE="${1:-}"
[[ -f "$FILE" ]] || { echo "usage: backbone-secret-check.sh <file>" >&2; exit 4; }

awk '
function placeholder(p) {
  return (p ~ /^<[^>]*>$/ || p ~ /^\{[^}]*\}$/ || p ~ /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/ || p ~ /^\*+$/ || p ~ /^[xX]+$/ || tolower(p) ~ /^(password|passwd|pass|secret|changeme)$/)
}
function report(label) { printf "line %d: %s\n", NR, label; found = 1 }
{
  line = $0
  # credentials in a connection string
  rest = line
  while (match(rest, /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^\/[:space:]:@]+:[^\/[:space:]@]+@/)) {
    seg = substr(rest, RSTART, RLENGTH)
    sub(/^[^:]*:\/\/[^:]*:/, "", seg); sub(/@$/, "", seg)
    if (!placeholder(seg)) { report("connection string with embedded credentials"); break }
    rest = substr(rest, RSTART + RLENGTH)
  }
  if (line ~ /[Bb]earer[[:space:]]+[A-Za-z0-9._~+\/=-]{16,}/) report("bearer token")
  if (line ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/) report("private key")
  if (line ~ /(AKIA|ASIA)[0-9A-Z]{16}/) report("AWS access key id")
  if (line ~ /gh[pousr]_[A-Za-z0-9]{30,}/) report("GitHub token")
  if (line ~ /xox[baprs]-[A-Za-z0-9-]{10,}/) report("Slack token")
  if (line ~ /sk-[A-Za-z0-9_-]{20,}/) report("API key (sk- prefix)")
  # long base64-looking token: >= 40 chars, with upper, lower and a digit
  rest = line
  while (match(rest, /[A-Za-z0-9+\/=]{40,}/)) {
    tok = substr(rest, RSTART, RLENGTH)
    if (tok ~ /[A-Z]/ && tok ~ /[a-z]/ && tok ~ /[0-9]/) { report("long base64-like token"); break }
    rest = substr(rest, RSTART + RLENGTH)
  }
}
END { exit found ? 1 : 0 }
' "$FILE"
