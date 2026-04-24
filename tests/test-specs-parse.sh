#!/bin/bash
#
# aidev toolkit specs-parse.sh Test Suite
#
# Tests all subcommands of specs-parse.sh with various fixtures
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSE_SCRIPT="$REPO_DIR/modules/sdd/scripts/specs-parse.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

# Helper functions
pass() { echo "  ✓ $1"; ((PASS++)) || true; }
fail() { echo "  ✗ $1"; ((FAIL++)) || true; }

# Run parser in fixture directory
run_parse() {
    local fixture="$1"
    local subcommand="$2"
    (cd "$FIXTURES_DIR/$fixture" && "$PARSE_SCRIPT" "$subcommand" 2>&1)
}

# Test: status subcommand with valid specs
test_status_valid() {
    echo ""
    echo "Test: status with valid specs"

    local output=$(run_parse "specs-valid" "status")

    # Check v1 in progress (2/3)
    if echo "$output" | grep -q "v1.*Feature Alpha.*2.*3.*In Progress"; then
        pass "v1 shows In Progress (2/3)"
    else
        fail "v1 status incorrect"
    fi

    # Check v2 draft (0/2)
    if echo "$output" | grep -q "v2.*Feature Beta.*0.*2.*Draft"; then
        pass "v2 shows Draft (0/2)"
    else
        fail "v2 status incorrect"
    fi

    # Check v3 complete (3/3)
    if echo "$output" | grep -q "v3.*Feature Gamma.*3.*3.*Complete"; then
        pass "v3 shows Complete (3/3)"
    else
        fail "v3 status incorrect"
    fi
}

# Test: status with empty spec (no checkboxes)
test_status_empty() {
    echo ""
    echo "Test: status with empty spec"

    local output=$(run_parse "specs-empty" "status")

    if echo "$output" | grep -q "v1.*No Tasks.*0.*0.*Empty"; then
        pass "Empty spec shows Empty status"
    else
        fail "Empty spec status incorrect"
    fi
}

# Test: status with malformed checkboxes
test_status_malformed() {
    echo ""
    echo "Test: status with malformed checkboxes"

    local output=$(run_parse "specs-malformed" "status")

    # Fixture has: 2 valid [x] items, 1 valid [ ] item, 1 malformed [] item (ignored)
    # Expected: 2 checked, 3 total -> In Progress
    if echo "$output" | grep -q "v1.*Bad Checkboxes.*2.*3.*In Progress"; then
        pass "Malformed checkboxes ignored correctly (2/3)"
    else
        fail "Malformed checkbox parsing incorrect: $output"
    fi
}

# Test: status with decimal versions
test_status_decimal() {
    echo ""
    echo "Test: status with decimal versions"

    local output=$(run_parse "specs-decimal" "status")

    # Check all versions present in output
    if echo "$output" | grep -q "v2\.1.*Urgent Fix"; then
        pass "Decimal version v2.1 parsed"
    else
        fail "v2.1 not found"
    fi

    if echo "$output" | grep -q "v8\.9.*Priority Feature"; then
        pass "Decimal version v8.9 parsed"
    else
        fail "v8.9 not found"
    fi

    # Verify correct order (should be sorted numerically: 2, 2.1, 3, 8.9, 9)
    local versions=$(echo "$output" | awk '{print $1}' | tr '\n' ' ')
    if [[ "$versions" =~ v2.*v2\.1.*v3.*v8\.9.*v9 ]]; then
        pass "Decimal versions sorted correctly"
    else
        fail "Decimal version sorting incorrect: $versions"
    fi
}

# Test: next-task finds first unchecked
test_next_task() {
    echo ""
    echo "Test: next-task finds first unchecked"

    local output=$(run_parse "specs-valid" "next-task")

    if echo "$output" | grep -q "spec_version: v1"; then
        pass "next-task found correct spec (v1)"
    else
        fail "next-task spec incorrect"
    fi

    if echo "$output" | grep -q "task: Task 3 pending"; then
        pass "next-task found correct task"
    else
        fail "next-task task incorrect"
    fi
}

# Test: next-task with all complete
test_next_task_complete() {
    echo ""
    echo "Test: next-task with all tasks complete"

    # Create temporary fixture with all tasks complete (specs-parse expects specs/README.md)
    local temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/specs"
    cat > "$temp_dir/specs/README.md" << 'EOF'
# Complete Spec

## Quick Status

| Version | Name | Progress | Status |
|---------|------|----------|--------|
| v1 | All Done | 2/2 | ✅ Complete |

---

## v1: All Done

### Phase 1: Done

- [x] Task 1
- [x] Task 2
EOF

    local output=$(cd "$temp_dir" && "$PARSE_SCRIPT" "next-task" 2>&1)
    rm -rf "$temp_dir"

    if echo "$output" | grep -q "NO_TASKS_REMAINING"; then
        pass "next-task returns NO_TASKS_REMAINING when complete"
    else
        fail "next-task should indicate no tasks remaining: $output"
    fi
}

# Test: next-phase with multiple phases
test_next_phase() {
    echo ""
    echo "Test: next-phase with multiple phases"

    local output=$(run_parse "specs-edge-cases" "next-phase")

    if echo "$output" | grep -q "spec_version: v1"; then
        pass "next-phase found correct spec"
    else
        fail "next-phase spec incorrect"
    fi

    if echo "$output" | grep -q "phase: Phase 1: First Phase"; then
        pass "next-phase found correct phase"
    else
        fail "next-phase phase incorrect"
    fi

    # Should list all tasks in Phase 1
    if echo "$output" | grep -q "Task 1" && echo "$output" | grep -q "Task 2"; then
        pass "next-phase lists all phase tasks"
    else
        fail "next-phase task list incomplete"
    fi
}

# Test: staleness detection
test_staleness() {
    echo ""
    echo "Test: staleness detection"

    # Create temporary fixture with spec file
    local temp_dir=$(mktemp -d)
    mkdir -p "$temp_dir/specs"

    cat > "$temp_dir/specs/README.md" << 'EOF'
# Test Staleness

## Quick Status

| Version | Name | Progress | Status |
|---------|------|----------|--------|
| v1 | Test | 1/2 | 🚀 In Progress |

---

## v1: Test

**Spec**: [spec-v1-test.md](spec-v1-test.md)

### Phase 1: Testing

- [x] Task 1
- [ ] Task 2
EOF

    cat > "$temp_dir/specs/spec-v1-test.md" << 'EOF'
---
version: 1
name: test
status: in-progress
---

# Test Spec
EOF

    # Touch spec file to make it newer than README
    sleep 1
    touch "$temp_dir/specs/spec-v1-test.md"

    local output=$(cd "$temp_dir" && "$PARSE_SCRIPT" "staleness" 2>&1)
    rm -rf "$temp_dir"

    if echo "$output" | grep -q "spec-v1-test.md"; then
        pass "staleness detects newer spec file"
    else
        fail "staleness detection incorrect: $output"
    fi
}

# Test: structure validation
test_structure_missing_readme() {
    echo ""
    echo "Test: structure detects missing README"

    local temp_dir=$(mktemp -d)
    local output=$(cd "$temp_dir" && "$PARSE_SCRIPT" "structure" 2>&1 || true)
    rm -rf "$temp_dir"

    if echo "$output" | grep -qi "missing\|not found"; then
        pass "structure detects missing README"
    else
        fail "structure should detect missing README: $output"
    fi
}

# Test: spec-list TSV output
test_spec_list() {
    echo ""
    echo "Test: spec-list TSV format"

    local output=$(run_parse "specs-valid" "spec-list")

    # Should be TSV format: version\tname\tstatus
    if echo "$output" | grep -q $'v1\t'; then
        pass "spec-list outputs TSV format"
    else
        fail "spec-list format incorrect"
    fi

    # Count tab-separated fields (skip the SPECS: header line)
    local field_count=$(echo "$output" | grep -v "^SPECS:" | head -1 | awk -F'\t' '{print NF}')
    if [ "$field_count" -ge 2 ]; then
        pass "spec-list has correct number of fields ($field_count)"
    else
        fail "spec-list field count incorrect: $field_count"
    fi
}

# Test: whitespace handling
test_whitespace() {
    echo ""
    echo "Test: whitespace handling"

    local output=$(run_parse "specs-edge-cases" "status")

    # Check that spec with whitespace variations is parsed
    if echo "$output" | grep -q "v2.*Whitespace Test"; then
        pass "Whitespace in spec name handled"
    else
        fail "Whitespace handling failed"
    fi

    # Should count valid checkboxes despite whitespace
    if echo "$output" | grep -q "v2.*1.*3"; then
        pass "Whitespace in checkboxes handled"
    else
        fail "Whitespace checkbox counting failed"
    fi
}

# Main test execution
echo ""
echo "aidev toolkit specs-parse.sh Test Suite"
echo "======================================="

# Verify parse script exists
if [ ! -f "$PARSE_SCRIPT" ]; then
    echo "ERROR: specs-parse.sh not found at $PARSE_SCRIPT"
    exit 1
fi

# Run all tests
test_status_valid
test_status_empty
test_status_malformed
test_status_decimal
test_next_task
test_next_task_complete
test_next_phase
test_staleness
test_structure_missing_readme
test_spec_list
test_whitespace

# Summary
echo ""
echo "======================================="
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
