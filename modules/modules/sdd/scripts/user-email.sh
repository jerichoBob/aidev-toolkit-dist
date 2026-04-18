#!/usr/bin/env bash
# User Email Management for SDD
# Manages persistent user identity via ~/.claude/aidev-toolkit/.user-email

set -euo pipefail

EMAIL_FILE="${HOME}/.claude/aidev-toolkit/.user-email"

# Get the stored email (returns empty string if not set)
get_email() {
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

# Check if email is configured, prompt if not
ensure_email() {
    local current_email
    current_email=$(get_email)

    if [[ -z "$current_email" ]]; then
        echo "⚠️  User email not configured." >&2
        echo "" >&2
        echo "To track spec ownership, please set your email address." >&2
        echo "This will be stored in: $EMAIL_FILE" >&2
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
    else
        echo "$current_email"
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
