#!/usr/bin/env bash
# User Email Management for SDD
# Manages persistent user identity via ~/.claude/aidev-toolkit/.user-email

set -euo pipefail

EMAIL_FILE="${HOME}/.claude/aidev-toolkit/.user-email"
AUTH_FILE="${HOME}/.claude/aidev-toolkit/.auth"

# Decode a JWT payload field without jq
jwt_field() {
    local token="$1" key="$2"
    local payload
    payload=$(echo "$token" | cut -d. -f2)
    local padded="$payload"
    local mod=$(( ${#payload} % 4 ))
    [[ $mod -eq 2 ]] && padded="${payload}=="
    [[ $mod -eq 3 ]] && padded="${payload}="
    echo "$padded" | tr '_-' '/+' | base64 --decode 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$key',''))" 2>/dev/null || echo ""
}

# Return email from JWT if present and not expired, else fall back to .user-email file
get_email() {
    # JWT identity takes priority when present and valid
    if [[ -f "$AUTH_FILE" ]]; then
        local token expires_at now
        token=$(cat "$AUTH_FILE")
        expires_at=$(jwt_field "$token" expires_at)
        now=$(date +%s)
        if [[ -n "$expires_at" ]] && (( expires_at > now )); then
            local email
            email=$(jwt_field "$token" github_email)
            [[ -n "$email" ]] && echo "$email" && return
        fi
    fi
    # Fall back to stored file
    if [[ -f "$EMAIL_FILE" ]]; then
        cat "$EMAIL_FILE" | tr -d '\n'
    else
        echo ""
    fi
}

# Set the email
set_email() {
    local email="$1"
    echo "$email" > "$EMAIL_FILE"
    chmod 600 "$EMAIL_FILE"
}

# Check if email is configured; use JWT identity if available, else prompt
ensure_email() {
    local current_email
    current_email=$(get_email)

    if [[ -n "$current_email" ]]; then
        echo "$current_email"
        return
    fi

    # No JWT and no stored email — prompt
    echo "⚠️  User email not configured." >&2
    echo "" >&2
    echo "Tip: run 'scripts/auth.sh login' to authenticate via GitHub (sets identity automatically)." >&2
    echo "Or enter your email manually below." >&2
    echo "" >&2
    read -p "Enter your email: " user_input

    if [[ -n "$user_input" ]]; then
        set_email "$user_input"
        echo "✅ Email saved: $user_input" >&2
        echo "$user_input"
    else
        echo "❌ Email is required for this operation." >&2
        return 1
    fi
}

# Main command routing
case "${1:-}" in
    get)
        get_email
        ;;
    set)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 set <email>" >&2
            exit 1
        fi
        set_email "$2"
        ;;
    ensure)
        ensure_email
        ;;
    *)
        echo "Usage: $0 {get|set|ensure} [email]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  get      - Get current email (empty if not set)" >&2
        echo "  set      - Set email address" >&2
        echo "  ensure   - Get email, prompting if not set" >&2
        exit 1
        ;;
esac
