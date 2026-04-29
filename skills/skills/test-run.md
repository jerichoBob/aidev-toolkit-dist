---
name: test-run
tier: extended
description: Run the full test suite and save a timestamped report to tests/results/.
allowed-tools: Bash(bash:*), Bash(ls:*), Bash(grep:*), Bash(date:*)
model: haiku
---

# Test Run

Execute the full test suite and write a timestamped report to `tests/results/`.

## Requirements

- `tests/run-all.sh` must exist in the current project
- `tests/results/` directory must exist (create with `mkdir -p tests/results`)

## Instructions

1. Verify the test runner exists:

```bash
ls tests/run-all.sh 2>/dev/null
```

If not found, display:

```text
No test runner found.
Expected: tests/run-all.sh
Create it to use /test-run.
```

Then stop.

2. Generate a timestamped filename:

```bash
REPORT_FILE="tests/results/run-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p tests/results
```

3. Run the full test suite and capture all output:

```bash
bash tests/run-all.sh 2>&1 | tee "$REPORT_FILE"
RUN_EXIT=$?
```

4. Parse the captured output from `$REPORT_FILE` to extract summary counts:
   - Count suites: number of lines matching `Running test-`
   - Count passed: sum all `N passed` values from `Results:` lines
   - Count failed: sum all `N failed` values from `Results:` lines
   - Count blocked: sum all `N blocked` values from `Results:` lines (or 0 if not present)

5. Display inline summary:

```text
────────────────────────────────────────
Test run complete
Report: tests/results/{filename}
────────────────────────────────────────
Suites:  N
Passed:  N
Failed:  N
Blocked: N (skipped)
────────────────────────────────────────
```

6. Exit with the same exit code as `run-all.sh` (non-zero if any suite failed).

## Notes

- Reports are saved to `tests/results/run-YYYYMMDD-HHMMSS.txt` and ignored by `.gitignore`
- Run `/test-status` to view the results table from the last saved report
- To prune old reports: `rm tests/results/run-*.txt`
