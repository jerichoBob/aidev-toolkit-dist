---
name: test-status
tier: extended
description: Display results from the last test run as a summary table (reads tests/results/ — does not re-run tests).
allowed-tools: Bash(bash:*), Bash(ls:*), Bash(grep:*), Read
model: haiku
---

# Test Status

Display the results of the last test run from `tests/results/`. Does **not** re-run tests.

## Instructions

1. Find the most recent report file:

```bash
REPORT=$(ls -t tests/results/run-*.txt 2>/dev/null | head -1)
```

If no report found, display:

```text
No test results found.
Run /test-run to execute the test suite first.
```

Then stop.

1. Display the report filename as a subtitle:

```text
Last run: {REPORT}
```

1. Read the report file content (use `cat "$REPORT"`).

2. Parse the output to extract per-suite results. For each suite, capture:
   - Suite name (from `Running test-{name}...`)
   - Pass count, fail count, blocked count (from `Results:` line)
   - Overall PASSED / FAILED status
   - Coverage description: read the comment block (lines 4–6 after the shebang) from `tests/{suite}.sh`

3. Display a markdown table:

```text
Test Suite Status
=================

Last run: tests/results/{filename}

| Suite | Coverage | Checks | Blocked | Status |
|---|---|---|---|---|
| test-auth | auth.sh status/token/logout against fixture JWTs | 8 passed, 0 failed | 2 | ✅ PASSED |
| test-frontmatter | YAML frontmatter in all skill files | 102 passed, 0 failed | — | ✅ PASSED |
...

Total: N suites — N passed, N failed
```

- **Coverage**: one-line summary extracted from the `#` comment block at the top of the test file (strip leading `#`)
- **Checks**: show `N passed, N failed` (omit if suite has no Results: line — just show status)
- **Blocked**: show count if > 0, otherwise `—`
- **Status**: ✅ PASSED or ❌ FAILED

1. If any suite failed, list its name under a `## Failures` heading with the failing test lines (lines containing `✗`).

2. If all pass, end with: `All suites green. Run \`/test-run\` for a fresh run.`
