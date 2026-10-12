#!/bin/bash
#
# Tests for the destructive-command guard (scripts/guard-destructive-commands.py)
# and its install/uninstall wiring. The work is in guard_destructive_commands_test.py
# (Python unittest, real temp dirs, no mocks, nothing here deletes anything).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "aidev toolkit test-guard-destructive-commands.sh Tests"
echo "======================================================="

if ! command -v python3 &> /dev/null; then
    echo "  ⊘ python3 not available [BLOCKED: python3 required]"
    exit 0
fi

if python3 -I "$SCRIPT_DIR/guard_destructive_commands_test.py"; then
    echo "Results: guard tests passed"
    exit 0
else
    echo "Results: guard tests FAILED"
    exit 1
fi
