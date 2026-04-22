---
name: arch-review
description: Validate codebase against aidev toolkit architecture principles.
argument-hint: "[--dry-run] [--principle <id>] [--fix] [--status] [--diff] [--scope <path>] [--ignore <pattern>] [--format json]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*)
model: inherit
---

# Architecture Principles Review

Validate the codebase against aidev toolkit architectural principles.

## When to Use

- User asks to "check architecture", "review against principles", or "validate codebase"
- Before major releases or code reviews
- When auditing security, observability, error handling, or test coverage
- After significant refactoring to ensure compliance

## Arguments

- `--dry-run`: Report findings without writing to review files
- `--principle <id>`: Check only a specific principle (e.g., `AP-001`)
- `--fix`: Attempt to auto-fix simple violations
- `--status`: Show violation history from previous reviews (skip new review)
- `--diff`: Run review and show only new/fixed violations since last review
- `--scope <path>`: Limit review to files under the specified path (e.g., `--scope src/`)
- `--ignore <pattern>`: Exclude paths or violation IDs matching the pattern (comma-separated, e.g., `--ignore vendor/,V-a3f2bc01`)
- `--format json`: Output results as machine-readable JSON instead of human-readable text
- (no argument): Full review, write results to `.aid/reviews/`

## Violation ID Scheme

Each violation gets a deterministic ID so the same issue produces the same ID across runs:

1. Concatenate: `{principle_id}:{checklist_item_text}:{file_path}`
2. Compute SHA-256 hash of the concatenated string
3. Take first 8 hex characters
4. Prefix with `V-` → e.g., `V-a3f2bc01`

This means:

- Same violation in same file = same ID (trackable across reviews)
- Same violation type in different file = different ID
- If the file path changes (refactor), it becomes a "new" violation and the old one shows as "fixed"

## Instructions

### Step 0: Handle --status (history mode)

If `$ARGUMENTS` contains `--status`:

1. Read all JSON files in `.aid/reviews/` (sorted by filename/timestamp)
2. Display a summary table:

```text
Arch Review History

Date                 Commit   Violations  New  Fixed
2026-02-10 14:30    abc1234   5           -    -
2026-02-11 09:15    def5678   3           0    2

Current: 3 open violations
  V-a3f2bc01  AP-001  Missing input validation  src/api/users.ts
  V-1b2c3d4e  AP-003  Empty catch block         src/services/auth.ts
  V-9e8f7a6b  AP-003  Empty catch block         src/services/payment.ts
```

1. Stop here — do not run a new review.

### Step 1: Load Principles

Read the architectural principles from `architecture-principles/*.md`:

- `architecture-principles/01-security.md` (AP-001)
- `architecture-principles/02-observability.md` (AP-002)
- `architecture-principles/03-error-handling.md` (AP-003)
- `architecture-principles/04-testing.md` (AP-004)
- `architecture-principles/05-security-first-sdd.md` (AP-005)

Also check for **custom project-level principles** in `.aid/principles/`:

- If `.aid/principles/` exists, read all `.md` files from it
- Custom principles use the same YAML frontmatter format (id, title, severity, category)
- Custom principle IDs should use a project prefix (e.g., `AP-P001`) to avoid collisions
- Custom principles are **additive** — they supplement, not override, core principles

If `--principle <id>` is specified, only load that one (works for both core and custom).

If architecture-principles directory doesn't exist, check if the aidev toolkit is installed. If not, inform the user:

```text
Architecture principles not found.
Install aidev toolkit or ensure architecture-principles/ directory exists.
```

### Step 2: Load Config

Check for `.aid/arch-review.yaml` config file. If it exists, read it for persistent settings:

```yaml
# .aid/arch-review.yaml
scope: [] # Default --scope paths (e.g., ["src/", "lib/"])
ignore: [] # Default --ignore patterns (e.g., ["vendor/", "*.test.ts"])
principles_dir: null # Override custom principles directory
retention_days: 90 # Auto-prune reviews older than N days
```

Command-line arguments override config file values.

### Step 3: Analyze Codebase

For each principle, check the validation checklist items.

**Scope filtering**: If `--scope <path>` is specified (or configured), only search within those paths. Otherwise search the entire project.

**Ignore filtering**: If `--ignore <pattern>` is specified (or configured), skip files/paths matching those patterns. Also skip violations whose IDs match ignore patterns.

#### AP-001: Security by Default

- [ ] No secrets or API keys in source code
- [ ] All database queries use parameterization or ORM
- [ ] External inputs are validated before use
- [ ] Authentication required on protected endpoints
- [ ] Authorization checks exist at resource level
- [ ] Dependencies scanned for known vulnerabilities

**Search patterns:**

- Hardcoded secrets: strings matching API key patterns, `password =`, etc.
- SQL injection: string concatenation in queries
- Missing validation: request body used directly without schema

#### AP-002: Observable Systems

- [ ] Logs are structured (JSON or equivalent)
- [ ] Correlation IDs present in log entries
- [ ] No sensitive data (passwords, tokens, PII) in logs
- [ ] Health endpoint exists and checks critical dependencies
- [ ] Appropriate log levels used
- [ ] Service name/version included in log context

**Search patterns:**

- Unstructured logging: `console.log`, `print()` in production code
- Missing correlation: HTTP handlers without correlation ID
- Health endpoints: `/health`, `/healthz`, `/ready` routes

#### AP-003: Intentional Error Handling

- [ ] No empty catch blocks
- [ ] All caught exceptions are logged with context
- [ ] Consistent error response format across APIs
- [ ] No stack traces or internal details exposed to clients
- [ ] Appropriate HTTP status codes used
- [ ] Centralized error handling in place
- [ ] Errors include correlation ID for tracing

**Search patterns:**

- Empty catch: `catch (e) {}`, `catch:` with pass/empty body
- Leaked internals: `stack` or `message` sent to client response
- Inconsistent errors: varying error response shapes

#### AP-004: Test Critical Paths

- [ ] Business logic has unit test coverage
- [ ] API endpoints have integration tests
- [ ] Auth flows are tested
- [ ] Dependencies are injectable (not hardcoded)
- [ ] No flaky tests in the test suite
- [ ] Test names describe expected behavior
- [ ] Critical user journeys have E2E coverage

**Search patterns:**

- Missing tests: source files without corresponding test files
- Hardcoded dependencies: `new Service()` instead of injection
- Unclear test names: `test1`, `it('works')`, etc.

#### AP-005: Security-First Spec Design

- [ ] Spec contains a `## Security` section
- [ ] Authentication subsection has an explicit decision (not placeholder text)
- [ ] Authorization subsection has an explicit decision (not placeholder text)
- [ ] Audit Logging subsection has an explicit decision (not placeholder text)
- [ ] Any "Not applicable" entries include a rationale

**Search patterns** (scan `specs/` directory):

- Spec files missing `## Security` section entirely
- Security subsections containing placeholder text: lines matching `\(e\.g\.,` or `\{e\.g\.,` that were never replaced
- Subsection headers with no content on the following lines

### Step 4: Assign Violation IDs

For each finding, compute the violation ID:

1. Build the string: `{principle_id}:{checklist_item}:{file_path}`
2. Hash with SHA-256 (use `echo -n "string" | shasum -a 256` in bash)
3. Take first 8 hex chars, prefix with `V-`

### Step 5: Report Findings

**Default (human-readable) output:**

```text
Architecture Review

Checking AP-001: Security by Default...
  [pass] No hardcoded secrets detected
  [FAIL] V-a3f2bc01 Missing input validation
         src/api/users.ts:45 - Request body used without validation

Checking AP-002: Observable Systems...
  [pass] Structured logging in use
  [FAIL] V-1b2c3d4e Missing correlation ID
         src/services/payment.ts:23 - No correlation header propagated

... (continue for each principle)

Summary
  Principles: 5 checked (+ N custom)
  Violations: X found
    AP-001: X
    AP-002: X
    AP-003: X
    AP-004: X

Exit code: {0|1|2} (see CI Integration section)
```

**If `--format json`:**

```json
{
  "timestamp": "2026-02-11T14:30:00Z",
  "commit": "abc1234",
  "branch": "main",
  "principles_checked": 4,
  "violations": [
    {
      "id": "V-a3f2bc01",
      "principle": "AP-001",
      "title": "Security by Default",
      "severity": "required",
      "checklist_item": "External inputs are validated before use",
      "finding": "Request body used without validation",
      "location": "src/api/users.ts:45",
      "recommendation": "Add zod/joi schema validation"
    }
  ],
  "summary": {
    "total_violations": 1,
    "by_principle": { "AP-001": 1, "AP-002": 0, "AP-003": 0, "AP-004": 0 },
    "by_severity": { "required": 1, "recommended": 0 }
  },
  "exit_code": 2
}
```

**If `--diff`:**

After computing current violations, load the most recent review from `.aid/reviews/` and compare by violation ID:

```text
Architecture Review (diff mode)

New violations (not in previous review):
  V-a3f2bc01  AP-001  Missing input validation  src/api/users.ts:45

Fixed violations (in previous review but not current):
  V-9e8f7a6b  AP-003  Empty catch block  src/services/payment.ts:12

Unchanged violations: 2

Summary: 1 new, 1 fixed, 2 unchanged
```

### Step 6: Persist Results (unless --dry-run)

If not `--dry-run`:

1. Create `.aid/reviews/` directory if it doesn't exist
2. Write results as JSON to `.aid/reviews/{ISO-timestamp}.json`:

```json
{
  "timestamp": "2026-02-11T14:30:00Z",
  "commit": "abc1234",
  "branch": "main",
  "scope": [],
  "ignore": [],
  "violations": [
    {
      "id": "V-a3f2bc01",
      "principle": "AP-001",
      "checklist_item": "External inputs are validated before use",
      "finding": "Request body used without validation",
      "location": "src/api/users.ts:45",
      "severity": "required",
      "recommendation": "Add zod/joi schema validation"
    }
  ],
  "summary": {
    "total_violations": 1,
    "by_principle": { "AP-001": 1 },
    "by_severity": { "required": 1 }
  }
}
```

1. **Prune old reviews**: If `retention_days` is configured (default: 90), delete review files older than that threshold.

### Step 7: Handle --fix (if specified)

For simple violations, attempt auto-fixes:

- Add `// TODO: ARCH -` comments for complex issues
- For empty catch blocks, add minimal logging
- For missing health endpoints, suggest code to add

After fixes, re-run the check to show updated status.

### Step 8: Exit Code

Report the exit code at the end of the review:

- **0**: No violations found (clean)
- **1**: Only `recommended` severity violations found (warnings)
- **2**: Any `required` severity violations found (failures)

In CI pipelines, this enables:

```bash
/arch-review --format json || exit $?
```

## Important Notes

- Be specific about locations. Always include file path and line number.
- Reference the actual code that violates the principle.
- Recommendations should be actionable and specific to this codebase.
- Don't report false positives. If unsure, note the uncertainty.
- Review JSON files should NOT be gitignored — violations should be tracked in version control.
- The old `.aid/arch-review.log` format is deprecated. If it exists, ignore it (don't delete it either).
