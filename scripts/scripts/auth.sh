#!/usr/bin/env bash
# scripts/auth.sh — aidev-toolkit GitHub OAuth authentication
#
# Usage:
#   auth.sh login    — open browser, complete OAuth, save JWT
#   auth.sh status   — show who is logged in and when token expires
#   auth.sh logout   — remove saved token
#   auth.sh token    — print raw JWT (for API calls)
#   auth.sh refresh  — renew token if within 7 days of expiry

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
WORKER_URL="https://aidev-auth.aidev-toolkit.workers.dev"
AIDEV_CLIENT_ID="Ov23lipRe973cOGquhk0"
AUTH_FILE="${HOME}/.claude/aidev-toolkit/.auth"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────────────

die() { echo -e "${RED}Error: $*${NC}" >&2; exit 1; }

# Decode a base64url-encoded JWT segment (no padding required)
b64url_decode() {
  local input="$1"
  local padded="$input"
  local mod=$(( ${#input} % 4 ))
  if [[ $mod -eq 2 ]]; then padded="${input}=="; fi
  if [[ $mod -eq 3 ]]; then padded="${input}="; fi
  # Translate base64url → base64, then decode
  echo "$padded" | tr '_-' '/+' | base64 --decode 2>/dev/null
}

# Extract a field from a JSON string (simple key lookup, no jq dependency)
json_field() {
  local json="$1" key="$2"
  echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$key',''))" 2>/dev/null
}

# Decode JWT payload section and extract a field
jwt_field() {
  local token="$1" key="$2"
  local payload
  payload=$(echo "$token" | cut -d. -f2)
  b64url_decode "$payload" | json_field /dev/stdin "$key" 2>/dev/null || \
    b64url_decode "$payload" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('$key',''))"
}

read_token() {
  [[ -f "$AUTH_FILE" ]] || die "Not logged in. Run: auth.sh login"
  cat "$AUTH_FILE"
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_login() {
  echo -e "${BLUE}aidev-toolkit Login${NC}"
  echo "==================="
  echo ""

  # Pick a random unprivileged port
  local port
  port=$(python3 -c "import random; print(random.randint(10000, 65000))")

  # Temp files scoped to this PID
  local token_file="/tmp/.aidev_token_$$"
  local server_pid=""

  cleanup_server() {
    rm -f "$token_file" "/tmp/.aidev_server_$$.py"
    [[ -n "$server_pid" ]] && kill "$server_pid" 2>/dev/null || true
  }
  trap cleanup_server EXIT

  # Write callback server to a temp file (more reliable than heredoc in background)
  local server_script="/tmp/.aidev_server_$$.py"
  cat > "$server_script" << 'PYEOF'
import http.server, urllib.parse, os, threading, socketserver, sys

PORT = int(os.environ['AIDEV_PORT'])
TOKEN_FILE = os.environ['AIDEV_TOKEN_FILE']

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        token = qs.get('token', [''])[0]
        error = qs.get('error', [''])[0]

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()

        if token:
            self.wfile.write(b'<html><body style="font-family:sans-serif;text-align:center;padding:60px">'
                             b'<h1>\xe2\x9c\x93 Authenticated!</h1>'
                             b'<p>You can close this tab and return to your terminal.</p>'
                             b'</body></html>')
            with open(TOKEN_FILE, 'w') as f:
                f.write(token)
        else:
            msg = ('Auth failed: ' + error).encode()
            self.wfile.write(b'<html><body style="font-family:sans-serif;text-align:center;padding:60px">'
                             b'<h1>Authentication Failed</h1><p>' + msg + b'</p></body></html>')
            with open(TOKEN_FILE, 'w') as f:
                f.write('ERROR:' + error)

        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def log_message(self, *args): pass

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', PORT), Handler) as httpd:
    httpd.serve_forever()
PYEOF

  AIDEV_PORT="$port" AIDEV_TOKEN_FILE="$token_file" python3 "$server_script" &
  server_pid=$!

  # Wait for server to be ready before opening browser
  local bind_wait=0
  while ! python3 -c "import socket; s=socket.socket(); s.connect(('127.0.0.1',$port)); s.close()" 2>/dev/null; do
    sleep 0.1
    (( bind_wait++ ))
    [[ $bind_wait -lt 30 ]] || die "Local callback server failed to start"
  done

  local login_url="${WORKER_URL}/login?redirect_port=${port}"
  echo "Opening browser for GitHub authentication..."
  echo -e "(URL: ${BLUE}${login_url}${NC})"
  echo ""
  open "$login_url" 2>/dev/null || xdg-open "$login_url" 2>/dev/null || \
    echo -e "${YELLOW}Could not auto-open browser. Open this URL manually:${NC}\n${login_url}"

  # Wait up to 60s for token file to appear
  local waited=0
  while [[ ! -f "$token_file" ]]; do
    sleep 1
    (( waited++ ))
    if (( waited >= 60 )); then
      die "Timed out waiting for authentication (60s). Try again."
    fi
  done

  local raw_token
  raw_token=$(cat "$token_file")

  if [[ "$raw_token" == ERROR:* ]]; then
    die "${raw_token#ERROR:}"
  fi

  # Basic JWT shape check (header.payload.sig)
  local parts
  parts=$(echo "$raw_token" | tr '.' '\n' | wc -l | tr -d ' ')
  [[ "$parts" -eq 3 ]] || die "Received malformed token from server"

  # Save token with restricted permissions
  install -m 600 /dev/null "$AUTH_FILE"
  echo "$raw_token" > "$AUTH_FILE"

  # Parse and display identity
  local login name expires_at
  login=$(jwt_field "$raw_token" github_login)
  name=$(jwt_field "$raw_token" name)
  expires_at=$(jwt_field "$raw_token" expires_at)
  local expiry_str
  expiry_str=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp(${expires_at}).strftime('%Y-%m-%d'))" 2>/dev/null || echo "unknown")

  echo -e "${GREEN}✓ Authenticated as @${login} (${name})${NC}"
  echo -e "  Token valid until: ${expiry_str}"
  echo -e "  Stored at: ${AUTH_FILE}"
}

cmd_status() {
  local token
  token=$(read_token)

  local login name email issued_at expires_at
  login=$(jwt_field "$token" github_login)
  name=$(jwt_field "$token" name)
  email=$(jwt_field "$token" github_email)
  issued_at=$(jwt_field "$token" issued_at)
  expires_at=$(jwt_field "$token" expires_at)

  local now
  now=$(date +%s)

  if (( expires_at < now )); then
    echo -e "${RED}Token expired${NC} — run: auth.sh login"
    exit 1
  fi

  local days_left issue_date expiry_date
  days_left=$(( (expires_at - now) / 86400 ))
  issue_date=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp(${issued_at}).strftime('%Y-%m-%d'))" 2>/dev/null || echo "?")
  expiry_date=$(python3 -c "import datetime; print(datetime.datetime.fromtimestamp(${expires_at}).strftime('%Y-%m-%d'))" 2>/dev/null || echo "?")

  echo -e "${GREEN}Logged in${NC}"
  echo "  GitHub login: @${login}"
  echo "  Name:         ${name}"
  echo "  Email:        ${email}"
  echo "  Issued:       ${issue_date}"
  echo "  Expires:      ${expiry_date} (${days_left} days)"

  if (( days_left <= 7 )); then
    echo -e "  ${YELLOW}⚠ Token expires soon. Run: auth.sh refresh${NC}"
  fi
}

cmd_logout() {
  if [[ -f "$AUTH_FILE" ]]; then
    rm -f "$AUTH_FILE"
    echo -e "${GREEN}✓ Logged out${NC} — token removed"
  else
    echo "Not logged in."
  fi
}

cmd_token() {
  read_token
}

cmd_refresh() {
  local token
  token=$(read_token)

  echo "Refreshing token..."
  local response http_code body
  response=$(curl -sf -w "\n%{http_code}" -X GET \
    -H "Authorization: Bearer ${token}" \
    "${WORKER_URL}/refresh" 2>/dev/null) || die "Failed to reach auth server"

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  case "$http_code" in
    200)
      local new_token
      new_token=$(echo "$body" | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")
      install -m 600 /dev/null "$AUTH_FILE"
      echo "$new_token" > "$AUTH_FILE"
      echo -e "${GREEN}✓ Token refreshed${NC}"
      cmd_status
      ;;
    400) echo "Token not near expiry — no refresh needed." ;;
    403) die "Access revoked. Contact the toolkit maintainer." ;;
    *)   die "Unexpected response from server (HTTP ${http_code})" ;;
  esac
}

# ── Entry point ───────────────────────────────────────────────────────────────

subcommand="${1:-status}"
shift 2>/dev/null || true

case "$subcommand" in
  login)   cmd_login ;;
  status)  cmd_status ;;
  logout)  cmd_logout ;;
  token)   cmd_token ;;
  refresh) cmd_refresh ;;
  *)
    echo "Usage: auth.sh <login|status|logout|token|refresh>"
    echo ""
    echo "  login    — authenticate via GitHub (browser-based)"
    echo "  status   — show current login and token expiry"
    echo "  logout   — remove saved token"
    echo "  token    — print raw JWT"
    echo "  refresh  — renew token if within 7 days of expiry"
    exit 1
    ;;
esac
