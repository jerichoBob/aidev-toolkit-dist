# aidev toolkit Help Reference

---

### If `$ARGUMENTS` is empty or blank

<!-- OUTPUT -->

## aidev toolkit v{VERSION}

### Toolkit & Documentation

- `/aid [command]` — Show this help, or help for a specific command
- `/aid-login` — Authenticate with GitHub (browser OAuth → JWT)
- `/aid-update` — Pull latest updates from GitHub
- `/aid-feedback` — Submit feedback or feature requests
- `/docs-update` — Update README.md and CLAUDE.md

### Identity & Auth

- `/aid-login` — Authenticate via browser-based GitHub OAuth; stores a JWT at `~/.claude/aidev-toolkit/.auth`
- `/aid-login status` — Show who is logged in and when the token expires
- `scripts/auth.sh logout` — Remove stored auth token
- `scripts/auth.sh refresh` — Silently renew token when within 7 days of expiry

### Analysis & Review

- `/inspect [options]` — Analyze and describe the current codebase
- `/arch-review` — Validate codebase against architecture principles
- `/deal-desk` — Deal qualification and risk assessment
- `/sdlc-plan` — Analyze business documents for implementation planning

### Development Tools

- `/commit` — Smart commit with grouping, versioning, changelog
- `/commit-push` — Same as /commit but auto-pushes
- `/analyze-changes` — Analyze git changes and determine version bump type (support skill)
- `/version-bump` — Bump version and update changelog (support skill)
- `/browser-harness` — Direct Chrome CDP control — install, connect, and run browser tasks
- `/code-stats [path]` — Count lines of code
- `/lint [target]` — Lint and fix markdown files
- `/screenshots [N]` — Load recent macOS screenshots into context
- `/should-i-trust-it` — Verify skill safety before installation
- `/remember [--user | --project] <content>` — Save knowledge to persistent memory
- `/aws-costs [--profile <name>] [--all-profiles]` — Show AWS spend by service, daily trend, and active resources

### Spec-Driven Development (SDD)

- `/sdd-init [--force]` — Scaffold `specs/` directory for a new SDD project
- `/sdd-spec-status <vN>` — Show phase-by-phase progress for a specific spec
- `/sdd-specs [--stats] [--deep] [--verify]` — Show specs status and token usage
- `/sdd-specs-update [--force]` — Sync project with SDD infrastructure
- `/sdd-spec <description>` — Create a new specification document
- `/sdd-spec-owner <version> [set <email> | unset]` — Set or unset spec owner (support skill)
- `/sdd-next` — Show the next task to implement
- `/sdd-next-phase` — Show all tasks in the current phase
- `/sdd-spec-prioritize [N]` — Recommend top N specs to focus on next (default: 5), then hand off to `/sdd-code-spec`
- `/sdd-code` — Implement the next single task
- `/sdd-code-phase` — Implement all tasks in current phase
- `/sdd-code-spec [version]` — Implement all remaining tasks in a spec
- `/sdd-spec-tagging` — Commit tagging convention reference
- `/sdd-specs-doctor [--dry-run]` — Migrate spec files to YAML frontmatter format
- `/sdd-specs-archive [--dry-run]` — Move completed specs to specs/completed/ to declutter active view

Run `/aid <command>` for detailed help on any command.

**Examples:**

```text
/aid                     Show all commands
/aid-update              Pull latest toolkit updates
/aid-feedback            Submit feedback or feature request
/docs-update             Update README.md and CLAUDE.md
/aid inspect             Show help for /inspect
/inspect                 Standard overview of current project
/inspect --brief         Quick reference (name, stack, commands)
/inspect --deep          Full analysis with patterns and domain model
/arch-review             Check architecture compliance
/deal-desk ./docs/       Analyze deal documents for risks
/deal-desk --quick       Fast deal assessment
/sdlc-plan @rfp.pdf      Analyze document for planning
/commit                  Analyze, group, commit, version bump
/commit-push             Commit and push in one step
/code-stats              Count lines of code in codebase
/lint                    Lint all markdown files
/lint docs/              Lint specific directory
/screenshots             Load most recent screenshot
/screenshots 3           Load last 3 screenshots
/sdd-init                Scaffold specs/ for a new project
/sdd-specs               Show specs status (default, fast)
/sdd-specs --stats       Show with token usage and costs
/sdd-specs --deep        Full scan with staleness report
/sdd-spec add CSV export Create a new spec
/sdd-code                Implement the next task
/sdd-code-phase          Implement entire current phase
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "update"

<!-- OUTPUT -->

The `/aid update` command has been replaced by `/aid-update`.

Run `/aid-update` to pull the latest toolkit updates.

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "inspect"

<!-- OUTPUT -->

## `/inspect` — Codebase Inspection

**Usage:** `/inspect [--brief | --deep]`

Analyze the current codebase and provide a structured overview. Think of it as "tell me about yourself" for any codebase.

**Options:**

| Flag        | Description                                            |
| ----------- | ------------------------------------------------------ |
| `--brief`   | Essential info only (name, stack, how to run)          |
| _(default)_ | Standard report with all sections                      |
| `--deep`    | Full analysis including code patterns and domain model |

**Detail Levels:**

- **brief** — Name, stack, install/run/test commands
- **standard** — Identity, architecture, tech stack, dev workflow, conventions, domain
- **deep** — All standard sections + code patterns, dependencies, domain model, architecture decisions, technical debt

**Examples:**

```text
/inspect            Standard overview
/inspect --brief    Quick reference for context switching
/inspect --deep     Deep dive for new team members
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "arch-review"

<!-- OUTPUT -->

## `/arch-review` — Architecture Principles Validation

**Usage:** `/arch-review [options]`

Validate the codebase against aidev toolkit architectural principles and document findings.

**Options:**

| Flag                 | Description                                            |
| -------------------- | ------------------------------------------------------ |
| `--dry-run`          | Report findings without writing to review files        |
| `--principle <id>`   | Check only a specific principle (AP-001, AP-002, etc.) |
| `--fix`              | Attempt to auto-fix simple violations                  |
| `--status`           | Show violation history from previous reviews           |
| `--diff`             | Show new/fixed violations since last review            |
| `--scope <path>`     | Limit review to files under a specific path            |
| `--ignore <pattern>` | Exclude paths or violation IDs (comma-separated)       |
| `--format json`      | Machine-readable JSON output for CI                    |

**Principles Checked:**

| ID     | Name                       | Covers                                          |
| ------ | -------------------------- | ----------------------------------------------- |
| AP-001 | Security by Default        | Input validation, secrets, auth, injection      |
| AP-002 | Observable Systems         | Structured logs, correlation IDs, health checks |
| AP-003 | Intentional Error Handling | No silent failures, consistent errors           |
| AP-004 | Test Critical Paths        | Test coverage, testable architecture            |
| AP-005 | Security-First Spec Design | Mandatory AuthN/AuthZ/audit section in every spec |

Custom project-level principles can be added in `.aid/principles/` (same YAML frontmatter format).

**Violation Tracking:**

Each violation gets a deterministic ID (e.g., `V-a3f2bc01`) based on principle + location. IDs persist across runs, enabling:

- `--status` to show history and fix progress
- `--diff` to show only new/fixed violations since last review

**Output:**

Console shows pass/fail for each check with violation IDs and details. Results are written as JSON to `.aid/reviews/` (unless `--dry-run`).

**Exit Codes (CI):**

| Code | Meaning                                         |
| ---- | ----------------------------------------------- |
| 0    | Clean — no violations                           |
| 1    | Warnings — only recommended-severity violations |
| 2    | Failures — required-severity violations found   |

**Config File:**

Persistent settings in `.aid/arch-review.yaml`:

```yaml
scope: ["src/"] # Default scope paths
ignore: ["vendor/"] # Default ignore patterns
retention_days: 90 # Auto-prune old reviews
```

**Examples:**

```text
/arch-review                     Full review, write to .aid/reviews/
/arch-review --dry-run           Preview without persisting
/arch-review --principle AP-001  Check only security principle
/arch-review --fix               Attempt auto-fixes where possible
/arch-review --status            Show violation history
/arch-review --diff              Show changes since last review
/arch-review --scope src/        Review only src/ directory
/arch-review --ignore vendor/    Skip vendor directory
/arch-review --format json       CI-friendly JSON output
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "commit"

<!-- OUTPUT -->

## `/commit` — Smart Commit

**Usage:** `/commit [version]`

Analyze changes, group them logically, commit each group with conventional commit messages, bump version, update changelog, then optionally push.

**Arguments:**

| Argument  | Description                                                       |
| --------- | ----------------------------------------------------------------- |
| `version` | Optional explicit version (e.g., 1.2.3) instead of auto-increment |

**Workflow:**

1. Pull latest from origin
2. Analyze changes and group logically
3. Commit each group with conventional commit message
4. Bump version (major/minor/patch based on changes)
5. Update changelog (CHANGELOG.md or README.md)
6. Commit version bump
7. Ask to push

**Commit Types:**

| Type       | Description        | Version Bump |
| ---------- | ------------------ | ------------ |
| `feat`     | New feature        | minor        |
| `fix`      | Bug fix            | patch        |
| `docs`     | Documentation      | patch        |
| `refactor` | Code restructuring | patch        |
| `test`     | Test changes       | patch        |
| `chore`    | Maintenance        | patch        |
| `feat!`    | Breaking change    | major        |

**Examples:**

```text
/commit              Auto-analyze and version bump
/commit 2.0.0        Force specific version
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "commit-push"

<!-- OUTPUT -->

## `/commit-push` — Smart Commit & Push

**Usage:** `/commit-push [version]`

Same as `/commit` but automatically pushes after committing. Does not ask for confirmation before push.

**Arguments:**

| Argument  | Description                                                       |
| --------- | ----------------------------------------------------------------- |
| `version` | Optional explicit version (e.g., 1.2.3) instead of auto-increment |

See `/aid commit` for full documentation.

**Examples:**

```text
/commit-push         Commit and push with auto-versioning
/commit-push 1.5.0   Commit with specific version and push
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "code-stats"

<!-- OUTPUT -->

## `/code-stats` — Code Statistics

**Usage:** `/code-stats [path]`

Count files and lines of code using cloc.

**Arguments:**

| Argument | Description                                                |
| -------- | ---------------------------------------------------------- |
| `path`   | Optional directory to analyze (default: current directory) |

**Output includes:**

- Files by language
- Blank lines, comments, and code lines
- Summary totals

**Prerequisites:**

Requires `cloc` to be installed:

- macOS: `brew install cloc`
- Ubuntu: `apt install cloc`

**Examples:**

```text
/code-stats          Analyze current directory
/code-stats src/     Analyze specific directory
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "lint"

<!-- OUTPUT -->

## `/lint` — Markdown Linter

**Usage:** `/lint [target]`

Lint and auto-fix markdown files using markdownlint.

**Arguments:**

| Target      | Description                                           |
| ----------- | ----------------------------------------------------- |
| _(empty)_   | Lint all .md files in current directory               |
| `file`      | Lint specific file (e.g., `/lint README.md`)          |
| `directory` | Lint all .md files in directory (e.g., `/lint docs/`) |
| `glob`      | Lint matching files (e.g., `/lint "specs/*.md"`)      |

**Workflow:**

1. Ensures `.markdownlint.json` config exists (copies from aidev toolkit defaults)
2. Runs `markdownlint --fix` to auto-fix simple issues
3. Manually fixes remaining markdownlint issues
4. Fixes line break issues (aidev toolkit enhancement)
5. Reports summary

**Common Rules Fixed:**

| Rule  | Description                               |
| ----- | ----------------------------------------- |
| MD022 | Headings need blank lines before/after    |
| MD031 | Code blocks need blank lines before/after |
| MD032 | Lists need blank lines before/after       |
| MD040 | Code blocks need language specifier       |
| MD047 | Files should end with newline             |

**aidev toolkit Enhancement:**

Detects consecutive `**Label**: Value` lines missing `<br/>` using awk, then adds line breaks so they render correctly (not collapsed).

**Prerequisites:**

Requires `markdownlint-cli`:

- `npm install -g markdownlint-cli`
- `brew install markdownlint-cli`

**Config:**

aidev toolkit config disables overly strict rules (line length, inline HTML). Project config created at `.markdownlint.json` for VS Code compatibility.

**Examples:**

```text
/lint                Lint all markdown in current directory
/lint README.md      Lint single file
/lint docs/          Lint all markdown in docs/
/lint "specs/*.md"   Lint matching glob pattern
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "risk-analysis"

<!-- OUTPUT -->

The `/risk-analysis` command has been renamed to `/deal-desk`.

Run `/deal-desk ./docs` to analyze deal documents for risks. Run `/aid deal-desk` for full documentation.

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "deal-desk"

<!-- OUTPUT -->

## `/deal-desk` — Deal Qualification & Risk Assessment

**Usage:** `/deal-desk [input] [options]`

Analyze project documents or codebase to assess risks and provide a Bid/No-Bid recommendation with deal score.

**Note:** Best results with Opus 4.5. Run: `claude --model opus /deal-desk ...`

**Input Modes:**

| Input         | Description                         |
| ------------- | ----------------------------------- |
| `<directory>` | Analyze all documents in directory  |
| `@<document>` | Analyze a single document           |
| `--codebase`  | Analyze current project code health |

**Perspective** (important):

| Flag            | Description                                            |
| --------------- | ------------------------------------------------------ |
| `--side vendor` | We are SELLING (default) — our protections = strengths |
| `--side buyer`  | We are BUYING — vendor protections = risks for us      |

**Options:**

| Flag               | Description                                              |
| ------------------ | -------------------------------------------------------- |
| `--quick`          | Deal score and summary only (no output files)            |
| `--deep`           | Comprehensive analysis with all 10 dimensions            |
| `--comprehensive`  | Rich format with visual scores, governance               |
| `--category <cat>` | Focus on specific category                               |
| `--output <dir>`   | Custom output directory (default: `./deal-desk-output/`) |
| `--pdf`            | Generate PDF report in addition to markdown              |

**Depth Levels:**

- **--quick** — Deal score, risk summary, red flags, top 5 risks
- **(default)** — Risk register, heat map, mitigations
- **--deep** — All dimensions + recommendations + open questions

**Risk Categories:**

| ID  | Category        | Covers                                   |
| --- | --------------- | ---------------------------------------- |
| R1  | Technical       | Complexity, dependencies, integration    |
| R2  | Schedule        | Timeline, milestones, critical path      |
| R3  | Scope           | Requirements gaps, ambiguity, creep      |
| R4  | Resource        | Skills, availability, team capacity      |
| R5  | Financial       | Cost drivers, budget, cash flow          |
| R6  | Compliance      | Regulatory, security, data protection    |
| R7  | Integration     | External systems, APIs, third-parties    |
| R8  | Operational     | Day-2, support, incidents, SLAs          |
| R9  | Organizational  | Change management, adoption, training    |
| R10 | Market/Business | Adoption, competition, value proposition |

**Deal Score (1-10):**

| Score | Verdict        | Meaning                               |
| ----- | -------------- | ------------------------------------- |
| 8-10  | GO             | Low risk, well-defined, good fit      |
| 5-7   | CONDITIONAL GO | Manageable risks, needs clarification |
| 3-4   | CAUTION        | Significant risks, consider carefully |
| 1-2   | NO-GO          | High risk, unclear scope, poor fit    |

**Output:**

Creates `deal-desk-output/` directory with:

| File                  | Contents                          |
| --------------------- | --------------------------------- |
| `README.md`           | Summary with deal score and links |
| `00-deal-summary.md`  | Deal score and recommendation     |
| `01-risk-register.md` | Full risk register table          |
| `02-risk-heatmap.md`  | Visual likelihood x impact grid   |
| `03-mitigations.md`   | Mitigation strategies             |
| `source-docs/`        | Copies of input documents         |

`--deep` adds files `04` through `09`. Also persists to `.aid/risks.yml` for tracking.

**Examples:**

```text
/deal-desk ./rfp-docs/              Analyze RFP documents (vendor perspective)
/deal-desk ./rfp-docs/ --side buyer Analyze as the buyer/client
/deal-desk @proposal.pdf            Analyze single document
/deal-desk --codebase               Assess current project health
/deal-desk ./docs --quick           Fast deal assessment
/deal-desk ./docs --deep            Full RFP response analysis
/deal-desk --category tech          Focus on technical risks
/deal-desk ./docs --pdf             Generate PDF report
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdlc-plan"

<!-- OUTPUT -->

## `/sdlc-plan` — Business Document Analysis

**Usage:** `/sdlc-plan @document [options]`

Analyze business documents (RFQ, RFP, PRD, SOW) and produce structured analysis for implementation planning.

**Input:**

| Input         | Description                      |
| ------------- | -------------------------------- |
| `@<document>` | Analyze a document (PDF, DOCX)   |
| `@doc1 @doc2` | Analyze with supplementary files |

**Options:**

| Flag             | Description                                       |
| ---------------- | ------------------------------------------------- |
| `--output <dir>` | Custom output directory (default: `./sdlc-plan/`) |

**Supported Document Types:**

| Type      | Description                    |
| --------- | ------------------------------ |
| RFQ/RFP   | Request for Quotation/Proposal |
| PRD       | Product Requirements Document  |
| SOW       | Statement of Work              |
| Tech Spec | Architecture/design document   |

**Output Structure:**

Creates `sdlc-plan/` directory with:

| File                           | Contents                                  |
| ------------------------------ | ----------------------------------------- |
| `README.md`                    | Index and summary                         |
| `01-executive-summary.md`      | Business context, goals, success criteria |
| `02-requirements-matrix.md`    | Requirements with IDs and priorities      |
| `03-technical-architecture.md` | System design and integrations            |
| `04-data-model.md`             | Entities and relationships                |
| `05-complexity-estimate.md`    | Risk factors and open questions           |
| `06-implementation-phases.md`  | Sprint/phase breakdown                    |

**Workflow:**

1. Reads and classifies the input document(s)
2. Presents summary for validation
3. Generates the 6 analysis documents
4. Suggests next steps (`/deal-desk`, `/spec`)

**Examples:**

```text
/sdlc-plan @rfp.pdf              Analyze an RFP document
/sdlc-plan @prd.docx             Analyze a PRD
/sdlc-plan @rfq.pdf @reqs.xlsx   Analyze with supplementary files
/sdlc-plan @sow.pdf --output ./project-analysis/
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "analyze"

<!-- OUTPUT -->

The `/analyze` command has been renamed to `/sdlc-plan`.

Run `/sdlc-plan @document` to analyze business documents. Run `/aid sdlc-plan` for full documentation.

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "should-i-trust-it"

<!-- OUTPUT -->

## `/should-i-trust-it` — Skill Security Verification

**Usage:** `/should-i-trust-it <skill> [options]`

Analyze a Claude Code skill file for potentially malicious patterns before installation.

**Arguments:**

| Argument | Description                                       |
| -------- | ------------------------------------------------- |
| `<path>` | Local path to skill markdown file                 |
| `<url>`  | URL to raw skill content (will fetch and analyze) |

**Options:**

| Flag         | Description                                                         |
| ------------ | ------------------------------------------------------------------- |
| `--detailed` | Show full skill content with suspicious lines highlighted           |
| `--json`     | Output structured JSON for automation                               |
| `--force`    | Acknowledge CRITICAL risk (required to proceed with blocked skills) |

**Risk Levels:**

| Level    | Meaning                                              |
| -------- | ---------------------------------------------------- |
| LOW      | Safe to use — matches trusted aidev-toolkit patterns |
| MEDIUM   | Review recommended — has some unusual patterns       |
| HIGH     | Manual review required — suspicious patterns found   |
| CRITICAL | Do not install — likely malicious                    |

**Pattern Categories Checked:**

- Network calls (`curl`, `wget`, `fetch`)
- Arbitrary execution (`eval`, `exec`, `bash -c`)
- Destructive operations (`rm -rf`, `git push --force`)
- Credential exfiltration (env + network)
- Git manipulation (commits without consent)
- Obfuscation (base64, hex encoding)

**Examples:**

```text
/should-i-trust-it ./my-skill.md
/should-i-trust-it https://raw.githubusercontent.com/.../skill.md
/should-i-trust-it ./suspicious.md --detailed
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "aid-feedback" or "feedback"

<!-- OUTPUT -->

## `/aid-feedback` — Submit Feedback / Ingest Feedback

**Usage:** `/aid-feedback [--ingest]`

Submit feedback to the aidev toolkit team via GitHub Issues, or (for maintainers) ingest open feedback issues and auto-create specs.

**Prerequisites:** `gh` CLI must be authenticated (`gh auth login`). No tokens, webhooks, or additional setup required.

**Arguments:**

| Argument   | Description                                                                            |
| ---------- | -------------------------------------------------------------------------------------- |
| _(empty)_  | Submit feedback interactively — or trigger ingestion mode if inside aidev-toolkit repo |
| `--ingest` | Force ingestion mode: read open feedback issues and create specs                       |

**Feedback Types (submission mode):**

| Type            | Description                       |
| --------------- | --------------------------------- |
| Feature Request | Suggest a new skill or capability |
| Bug Report      | Something isn't working correctly |
| Improvement     | Enhance an existing skill         |
| Documentation   | Docs unclear or missing           |

**Submission Workflow:**

1. Answer prompts about feedback type and area
2. Provide detailed description
3. Posted as a GitHub Issue on `jerichoBob/aidev-toolkit` with `feedback` label

**Ingestion Mode (maintainers only):**

Ingestion mode triggers automatically when run from inside the aidev-toolkit project directory. It:

1. Reads open issues labeled `feedback` from `jerichoBob/aidev-toolkit`
2. Classifies, deduplicates, and priority-sorts items
3. Presents a numbered list for confirmation
4. Calls `/sdd-spec` for each confirmed item
5. Labels processed issues as `processed`

**Ingestion trigger conditions (both must be true):**

- `$ARGUMENTS` is empty or `--ingest`
- `modules/sdd/` directory exists in CWD (confirms aidev-toolkit project)

**Examples:**

```text
/aid-feedback              Submit feedback (or ingest if inside aidev-toolkit)
/aid-feedback --ingest     Force ingestion mode
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "docs-update"

<!-- OUTPUT -->

## `/docs-update` — Documentation Update

**Usage:** `/docs-update [--deep]`

Update README.md and CLAUDE.md to reflect the current codebase state.

**Arguments:**

| Argument  | Description                                                   |
| --------- | ------------------------------------------------------------- |
| _(empty)_ | Update top-level README.md and CLAUDE.md only                 |
| `--deep`  | Scan ALL README.md and CLAUDE.md in repo, plus run deep audit |

**What It Does:**

1. Reads existing documentation
2. Scans codebase for current structure, features, commands
3. Identifies gaps between docs and reality
4. Updates documentation to match current state

**Updates Include:**

- New features or commands not documented
- Changed paths or renamed files
- Removed or deprecated items
- Updated installation instructions
- Current file structure

**Preserves:**

- Existing changelog/version history
- Document tone and style
- Custom sections

**`--deep` Audit (in addition to recursive file scan):**

| Check                   | What It Does                                                                             |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| Spec cross-reference    | Reads `specs/README.md`, updates stale spec rows in project README, adds missing specs   |
| Tech stack verification | Compares version claims in README against `package.json`/`go.mod`/etc.; flags mismatches |
| Path verification       | Checks that file paths referenced in README actually exist on disk; flags broken paths   |

**Examples:**

```text
/docs-update           Update top-level docs only
/docs-update --deep    Update all docs + run deep audit (spec sync, version check, path check)
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "screenshots"

<!-- OUTPUT -->

## `/screenshots` — Load Recent Screenshots

**Usage:** `/screenshots [N]`

Load the N most recent macOS screenshots from ~/Desktop into context. Claude natively views PNG images, so loaded screenshots are immediately available for discussion, analysis, or reference.

**Arguments:**

| Argument  | Description                                  |
| --------- | -------------------------------------------- |
| _(empty)_ | Load the most recent screenshot (default: 1) |
| `N`       | Load the N most recent screenshots           |

**How It Works:**

1. Finds `Screenshot*.png` files on `~/Desktop` sorted by modification time
2. Returns the N most recent (newest first)
3. Reads each file so Claude can see the image

**Examples:**

```text
/screenshots             Load the most recent screenshot
/screenshots 3           Load the last 3 screenshots
/screenshots 10          Load the last 10 screenshots
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-specs"

<!-- OUTPUT -->

## `/sdd-specs` — Specs Status Overview

**Usage:** `/sdd-specs [--stats] [--deep] [--verify]`

Display specs status with optional token usage metrics and detailed validation.

**Options:**

| Flag        | Description                                        |
| ----------- | -------------------------------------------------- |
| _(default)_ | Fast path: status table only                       |
| `--stats`   | Show token usage columns and cost estimates        |
| `--deep`    | Deep scan: staleness detection and validation      |
| `--verify`  | Verify all tasks against codebase (implies --deep) |

**Paths:**

**Fast Path** (default):

- Reads `specs/README.md` only (very fast)
- Displays Quick Status table with progress
- Shows task counts and completion percentage
- No network or filesystem scanning

**Stats Path** (`--stats`):

- Reads token metadata from README HTML comments
- Displays enhanced table with token columns: In, Out, Cache, Duration
- Shows estimated costs based on actual usage
- Aggregates metrics across all specs with metadata
- Format: `/sdd-specs --stats`

**Deep Scan Path** (`--deep` or `--verify`):

- Parses `specs/README.md` for spec headers and checkbox counts
- Displays status table with progress per spec
- Checks for stale spec files (newer than README)
- Auto-updates README if progress numbers are wrong
- With `--verify`: searches codebase to confirm completed tasks

**Token Usage Metadata:**

When specs are implemented with token tracking enabled:

- Each task stores metadata as HTML comments in README
- Tokens captured: input, output, cache read
- Cost calculated using Anthropic pricing:
  - Input: \$3.00 per 1M tokens
  - Output: \$15.00 per 1M tokens
  - Cache: \$0.30 per 1M tokens

**Prerequisite:** Project must have a `specs/` directory. Run `/sdd-specs-update` first.

**Examples:**

```text
/sdd-specs               Show status table (default, fast)
/sdd-specs --stats       Show with token usage and costs
/sdd-specs --deep        Full scan with staleness report
/sdd-specs --verify      Full verification against code
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-init"

<!-- OUTPUT -->

## `/sdd-init` — Initialize SDD for a New Project

**Usage:** `/sdd-init [--force]`

Scaffold the `specs/` directory so it's ready for Spec-Driven Development. This is the first command to run in any new project before using `/sdd-spec`.

**What It Creates:**

- `specs/` directory (if missing)
- `specs/TEMPLATE.md` — copied from the toolkit's canonical template
- `specs/README.md` — standard Quick Status table + Architecture section placeholder

**Options:**

| Flag        | Description                                                 |
| ----------- | ----------------------------------------------------------- |
| _(default)_ | Safe/idempotent — skips existing files                      |
| `--force`   | Overwrite existing `specs/README.md` (prints warning first) |

**Idempotent:** Safe to run on existing projects. Existing files are skipped unless `--force` is passed.

**Examples:**

```text
/sdd-init           Initialize specs/ in a new project
/sdd-init --force   Reinitialize (overwrites README.md)
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-spec-status"

<!-- OUTPUT -->

## `/sdd-spec-status` — Phase-by-Phase Spec Progress

**Usage:** `/sdd-spec-status <vN>`

Show a phase-by-phase breakdown of progress for a specific spec.

**Output:**

```text
v21: Feedback Ingestion & Spec Generation — 3/15

  ✅ Phase 1: Slack Integration (3/3)
  🔧 Phase 2: Feedback Analysis & Prioritization (0/4)
  ⬜ Phase 3: Spec Generation (0/3)
  ⬜ Phase 4: Documentation (0/3)
```

**Status indicators:**

| Emoji | Meaning                       |
| ----- | ----------------------------- |
| ✅    | All tasks complete            |
| 🔧    | In progress (some tasks done) |
| ⬜    | Not started                   |

**Examples:**

```text
/sdd-spec-status v21     Show phase breakdown for v21
/sdd-spec-status 17      Version number without "v" also works
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-specs-update"

<!-- OUTPUT -->

## `/sdd-specs-update` — Sync SDD Infrastructure

**Usage:** `/sdd-specs-update [--force]`

Initialize or sync a project with SDD methodology infrastructure.

**Options:**

| Flag        | Description                                           |
| ----------- | ----------------------------------------------------- |
| _(default)_ | Add missing structure only                            |
| `--force`   | Also update existing methodology section in CLAUDE.md |

**What It Creates/Syncs:**

- `specs/` directory
- `specs/TEMPLATE.md` (canonical spec template)
- `specs/README.md` (progress tracking scaffold)
- Development Methodology section in `.claude/CLAUDE.md`

**Idempotent:** Safe to run multiple times. Only adds missing structure.

**Examples:**

```text
/sdd-specs-update          Initialize SDD in a project
/sdd-specs-update --force  Force-update methodology section
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-spec"

<!-- OUTPUT -->

## `/sdd-spec` — Create New Specification

**Usage:** `/sdd-spec <description>`

Create a new specification document from a description.

**Arguments:**

| Argument      | Description                               |
| ------------- | ----------------------------------------- |
| `description` | What the spec is about (natural language) |

**Workflow:**

1. Finds highest existing spec version, increments by 1
2. Creates kebab-case filename: `spec-v{N}-{short-name}.md`
3. Fills template with Why/What/How from your description
4. Updates `specs/README.md` with new spec section

**Examples:**

```text
/sdd-spec add CSV export functionality
/sdd-spec implement user authentication with OAuth
/sdd-spec refactor database layer for connection pooling
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-next"

<!-- OUTPUT -->

## `/sdd-next` — Show Next Task

**Usage:** `/sdd-next`

Show the next task that would be implemented if `/sdd-code` is run. Displays the spec, phase, task, and a brief preview of what implementation would involve.

**Examples:**

```text
/sdd-next                Show what's next to implement
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-spec-prioritize"

<!-- OUTPUT -->

## `/sdd-spec-prioritize` — Prioritize Next Specs

**Usage:** `/sdd-spec-prioritize`

Analyze all active (incomplete) specs and recommend the top N to focus on next (default: 5). Reads each spec file to assess type, scope, dependencies, and value — then ranks them with one-paragraph reasoning per recommendation. After displaying results, prompts you to pick a spec and hands off directly to `/sdd-code-spec`.

**Examples:**

```text
/sdd-spec-prioritize          Show top 5 specs to work on next
/sdd-spec-prioritize 10       Show top 10 specs
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-next-phase"

<!-- OUTPUT -->

## `/sdd-next-phase` — Show Next Phase

**Usage:** `/sdd-next-phase`

Show all tasks in the current working phase with their completion status and progress summary.

**Examples:**

```text
/sdd-next-phase          Show all tasks in current phase
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-code"

<!-- OUTPUT -->

## `/sdd-code` — Implement Next Task

**Usage:** `/sdd-code`

Implement the single next unchecked task from the specs checklist. Reads the spec for context, implements the task, updates the README checklist, and reports completion.

**Workflow:**

1. Finds next unchecked task in `specs/README.md`
2. Reads the spec file for implementation context
3. Implements the task following existing code patterns
4. Marks the task complete in README (`- [x]`)
5. Reports what was done and previews the next task

**Important:** Implements only ONE task per invocation.

**Examples:**

```text
/sdd-code                Implement the next task
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-code-phase"

<!-- OUTPUT -->

## `/sdd-code-phase` — Implement Current Phase

**Usage:** `/sdd-code-phase`

Implement all remaining tasks in the current phase without stopping. Works through each task sequentially, updating the checklist after each one.

**Workflow:**

1. Gets all tasks in the current working phase
2. Implements each unchecked task sequentially
3. Updates README after each task
4. Runs tests if available
5. Reports phase completion summary

**Important:** Does not stop between tasks — implements the entire phase.

**Examples:**

```text
/sdd-code-phase          Implement all tasks in current phase
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-code-spec"

<!-- OUTPUT -->

## `/sdd-code-spec` — Implement Complete Spec

**Usage:** `/sdd-code-spec [version]`

Implement all remaining phases and tasks in a spec without stopping.

**Arguments:**

| Argument  | Description                                                                  |
| --------- | ---------------------------------------------------------------------------- |
| `version` | Optional spec version (e.g., `v3`). Defaults to first In Progress/Draft spec |

**Workflow:**

1. Identifies target spec and all remaining work
2. Implements phase-by-phase, task-by-task
3. Updates README after each task
4. Marks blocked tasks and continues
5. Reports full completion summary

**Important:** Does not stop between tasks or phases — implements end-to-end.

**Examples:**

```text
/sdd-code-spec           Implement first active spec
/sdd-code-spec v3        Implement spec v3 specifically
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-specs-doctor"

<!-- OUTPUT -->

## `/sdd-specs-doctor` — Migrate Spec Files to Current Format

**Usage:** `/sdd-specs-doctor [--dry-run]`

Scan `specs/spec-v*.md` files and migrate them from the old format (inline metadata, checkboxes) to the current YAML frontmatter format.

**Options:**

| Flag        | Description                                      |
| ----------- | ------------------------------------------------ |
| _(default)_ | Detect and fix all format issues                 |
| `--dry-run` | Report what would change without modifying files |

**What It Detects & Fixes:**

| Issue      | Old Format                  | New Format               |
| ---------- | --------------------------- | ------------------------ |
| Metadata   | `**Version**: v3` inline    | YAML frontmatter block   |
| Checkboxes | `- [x] Task` / `- [ ] Task` | `- Task` (plain bullets) |
| Heading    | `## How (Implementation)`   | `## How (Approach)`      |

**Idempotent:** Safe to run multiple times. Skips files that are already in the current format.

**Note:** Never modifies `specs/README.md` or `specs/TEMPLATE.md` — only spec files.

**Examples:**

```text
/sdd-specs-doctor              Migrate all old-format spec files
/sdd-specs-doctor --dry-run    Preview changes without modifying
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-specs-archive"

<!-- OUTPUT -->

## `/sdd-specs-archive` — Archive Completed Specs

**Usage:** `/sdd-specs-archive [--dry-run]`

Move all `✅ Complete` spec files from `specs/` to `specs/completed/` and mark them as `🗄 Archived` in `specs/README.md`. This keeps `/sdd-specs` focused on active work.

**Options:**

| Flag        | Description                                                       |
| ----------- | ----------------------------------------------------------------- |
| _(default)_ | Interactive — shows what will be archived, confirms before moving |
| `--dry-run` | Preview only — no files moved, no README changes                  |

**After archiving:**

- `/sdd-specs` — shows only active (Draft/In Progress) specs
- `/sdd-specs --archived` — shows archived specs
- `/sdd-specs --all` — shows everything

**Example:**

```text
/sdd-specs-archive              Archive all completed specs
/sdd-specs-archive --dry-run    Preview what would be archived
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd-spec-tagging"

<!-- OUTPUT -->

## `/sdd-spec-tagging` — Commit Tagging Convention

**Status:** PROPOSED (reference document)

A convention for traceable spec-to-code mapping using `[vN:pN:sN]` tags in commit messages.

**Format:** `[v{VERSION}:p{PHASE}:s{STEP}]`

**Example:**

```text
feat: add interaction logging [v7:p1:s5]
```

**Benefits:**

- Fast verification via `git log --grep`
- Definitive spec-to-commit traceability
- Works with `/sdd-specs --verify`

Run `/sdd-spec-tagging` for full documentation.

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "sdd"

<!-- OUTPUT -->

## Spec-Driven Development (SDD) — Full Pipeline

SDD is a 3-stage pipeline that takes you from business analysis through coded implementation, with specs as the single source of truth.

---

### Stage 1: Analyze

Understand the problem before writing specs.

| Command      | Purpose                                               |
| ------------ | ----------------------------------------------------- |
| `/deal-desk` | Risk assessment and Bid/No-Bid recommendation         |
| `/sdlc-plan` | Break business documents into requirements and phases |

---

### Stage 2: Specify

Create and track specifications.

| Command                 | Purpose                                                      |
| ----------------------- | ------------------------------------------------------------ |
| `/sdd-init [--force]`   | Scaffold `specs/` for a new project (first command to run)   |
| `/sdd-specs-update`     | Sync SDD infrastructure — adds CLAUDE.md methodology section |
| `/sdd-spec <desc>`      | Create a new spec from a description                         |
| `/sdd-spec-status <vN>` | Phase-by-phase progress for a specific spec                  |
| `/sdd-specs`            | Show status table — progress, staleness, completeness        |
| `/sdd-specs-doctor`     | Migrate old-format spec files to YAML frontmatter            |

---

### Stage 3: Implement

Code against the spec checklist.

| Command                    | Purpose                                             |
| -------------------------- | --------------------------------------------------- |
| `/sdd-spec-prioritize [N]` | Recommend top N specs to focus on next (default: 5) |
| `/sdd-next`                | Preview the next task to implement                  |
| `/sdd-next-phase`          | Preview all tasks in the current phase              |
| `/sdd-code`                | Implement the single next task                      |
| `/sdd-code-phase`          | Implement all tasks in the current phase            |
| `/sdd-code-spec [vN]`      | Implement an entire spec end-to-end                 |
| `/sdd-spec-tagging`        | Commit tagging convention (`[vN:pN:sN]`)            |

---

### Typical Workflow

```text
# 1. Analyze the deal/project
/deal-desk ./rfp-docs/
/sdlc-plan @requirements.pdf

# 2. Initialize specs and create first spec
/sdd-specs-update
/sdd-spec add user authentication with OAuth

# 3. Check what's next and start coding
/sdd-specs
/sdd-next
/sdd-code

# 4. Implement a full phase or full spec
/sdd-code-phase
/sdd-code-spec v1
```

Run `/aid <command>` for detailed help on any individual command.

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "aws-costs"

<!-- OUTPUT -->

## `/aws-costs` — AWS Spend Monitor

**Usage:** `/aws-costs [--profile <name>] [--all-profiles]`

Show current AWS spend broken down by service, daily trend for the last 7 days, and active running resources.

**Arguments:**

| Argument           | Description                                   |
| ------------------ | --------------------------------------------- |
| _(empty)_          | Default AWS profile                           |
| `--profile <name>` | Specific named profile from `~/.aws/config`   |
| `--all-profiles`   | All configured profiles with combined summary |

**Output includes:**

- Current month spend by service (sorted descending, non-zero only)
- Daily trend for last 7 days with ↑/↓ delta
- Active resources: EC2 instances, NAT gateways, ALBs, RDS (with estimated hourly rates)
- Threshold alert if `~/.aws-costs-config.json` sets `alertThreshold`

**Prerequisites:**

- AWS CLI v2 installed (`brew install awscli`)
- Credentials configured (`aws configure`)
- Cost Explorer enabled in AWS account (one-time setup, free tier available)

**Threshold config** (`~/.aws-costs-config.json`):

```json
{ "alertThreshold": 100.0 }
```

**Examples:**

```text
/aws-costs                       Default profile, current month
/aws-costs --profile work        Specific named profile
/aws-costs --all-profiles        All profiles, combined summary
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "remember"

<!-- OUTPUT -->

## `/remember` — Save to Persistent Memory

**Usage:** `/remember [--user | --project] <content>`

Save a piece of knowledge, preference, or instruction to persistent memory so it's available in future conversations.

**Arguments:**

| Argument    | Description                                                      |
| ----------- | ---------------------------------------------------------------- |
| `--user`    | Save to `~/.claude/CLAUDE.md` (global — applies to ALL projects) |
| `--project` | Save to the project's `memory/MEMORY.md` (project scope only)    |
| _(no flag)_ | Ask interactively: global or project?                            |
| `content`   | The knowledge, preference, or instruction to save                |

**Examples:**

```text
/remember --user always use pnpm, not npm
/remember --project the API rate limit is 100 req/min per tenant
/remember the design system uses 8px grid spacing
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is "auth"

<!-- OUTPUT -->

## `scripts/auth.sh` — Identity & Authentication

**Usage:** `~/.claude/aidev-toolkit/scripts/auth.sh <command>`

Authenticate aidev toolkit via browser-based GitHub OAuth. Stores a signed JWT at `~/.claude/aidev-toolkit/.auth` (chmod 600).

**Commands:**

| Command   | Description                                                              |
| --------- | ------------------------------------------------------------------------ |
| `login`   | Open browser → GitHub OAuth → capture JWT → store at `.auth`            |
| `status`  | Decode and display `@github_login`, name, email, and token expiry        |
| `logout`  | Remove stored `.auth` file                                               |
| `token`   | Print raw JWT (for debugging or API calls)                               |
| `refresh` | Renew token silently when within 7 days of expiry                        |

**Login flow:**

1. Opens a browser tab to the aidev auth Worker
2. You approve access on GitHub
3. A short-lived JWT is captured and stored locally
4. `user-email.sh` automatically uses the JWT identity going forward

**Security:**

- The GitHub OAuth client secret lives **only** in the Cloudflare Worker — never on your machine
- The JWT is stored at `chmod 600` — readable only by your user
- Token expires after 30 days; refresh renews automatically

**Examples:**

```text
scripts/auth.sh login      Authenticate (opens browser)
scripts/auth.sh status     Who am I? When does my token expire?
scripts/auth.sh logout     Sign out / revoke local token
scripts/auth.sh refresh    Renew token without re-authenticating
```

<!-- /OUTPUT -->

---

### If `$ARGUMENTS` is anything else (unknown command)

<!-- OUTPUT -->

Unknown command: `<argument>`

Run `/aid` to see available commands.

<!-- /OUTPUT -->
