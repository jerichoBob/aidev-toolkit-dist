# aidev-toolkit

A collection of AI-enabled SDLC tools for AI developers.

## Installation

### Using GitHub CLI (Recommended)

```bash
gh repo clone jerichoBob/aidev-toolkit-dist-dist ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh
```

### Using SSH

```bash
git clone git@github.com:jerichoBob/aidev-toolkit-dist-dist.git ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh
```

### Using HTTPS (requires credential helper)

```bash
git clone https://github.com/jerichoBob/aidev-toolkit-dist-dist.git ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh
```

This:

- Clones the repo to `~/.claude/aidev-toolkit/`
- Symlinks skills to `~/.claude/commands/` and `~/.claude/skills/`
- Configures permissions and symlinks skills into `~/.claude/commands/`

After installation:

```text
~/.claude/
├── commands/
│   ├── aid.md -> ../aidev-toolkit/skills/aid.md
│   ├── commit.md -> ../aidev-toolkit/skills/commit.md
│   ├── ...                (14 core skills)
│   ├── sdd-code.md -> ../aidev-toolkit/modules/sdd/skills/sdd-code.md
│   ├── sdd-specs.md -> ../aidev-toolkit/modules/sdd/skills/sdd-specs.md
│   └── ...                (9 SDD skills)
├── skills/
│   └── (same symlinks as commands/)
└── aidev-toolkit/              <- git clone
    ├── architecture-principles/
    ├── scripts/
    ├── skills/
    ├── modules/
    │   └── sdd/              <- Spec-Driven Development
    │       ├── scripts/
    │       ├── skills/
    │       └── templates/
    ├── templates/            <- Formatted output helpers
    |   ├── deal-desk/
    |   ├── pdf/
    │   └── markdownlint
    └── ...
```

## Quick Start

```bash
# Install aidev toolkit (using GitHub CLI)
gh repo clone jerichoBob/aidev-toolkit-dist-dist ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh

# Go to your project
cd your-project

# Start Claude Code
claude

# See available commands
/aid
```

## What's Included

### Skills (User-Invocable Commands)

These are symlinked to `~/.claude/commands/` and `~/.claude/skills/` so you can invoke them with `/` in Claude Code.

**Toolkit**

| Command         | Description                                    |
| --------------- | ---------------------------------------------- |
| `/aid`          | Show this help, or help for a specific command |
| `/aid-update`   | Pull latest updates from GitHub                |
| `/docs-update`  | Update README.md and CLAUDE.md                 |
| `/aid-feedback` | Submit feedback or feature requests            |

**Analysis**

| Command        | Description                                                  |
| -------------- | ------------------------------------------------------------ |
| `/arch-review` | Validate codebase against architecture principles            |
| `/deal-desk`   | Deal qualification and risk assessment                       |
| `/inspect`     | Analyze any codebase - identity, architecture, tech stack    |
| `/sdlc-plan`   | Analyze business documents (RFQ, RFP, PRD, SOW) for planning |

**Browser Automation**

| Command             | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| `/browser-harness`  | Direct Chrome CDP control — install, connect, and run tasks  |

**Development**

| Command              | Description                                       |
| -------------------- | ------------------------------------------------- |
| `/code-stats`        | Count lines of code by language using cloc        |
| `/commit`            | Smart commit with grouping, versioning, changelog |
| `/commit-push`       | Same as /commit but auto-pushes                   |
| `/lint`              | Lint and fix markdown files                       |
| `/should-i-trust-it` | Verify skill safety before installation           |

**Spec-Driven Development (SDD)**

| Command             | Description                                    |
| ------------------- | ---------------------------------------------- |
| `/sdd-specs`        | Show specs status, staleness, progress summary |
| `/sdd-specs-update` | Sync project with SDD infrastructure           |
| `/sdd-spec`         | Create a new specification document            |
| `/sdd-next`         | Show the next task to implement                |
| `/sdd-next-phase`   | Show all tasks in the current phase            |
| `/sdd-code`         | Implement the next single task                 |
| `/sdd-code-phase`   | Implement all tasks in current phase           |
| `/sdd-code-spec`    | Implement all remaining tasks in a spec        |
| `/sdd-spec-tagging` | Commit tagging convention reference            |

### Support Skills

These are called by other skills and are not intended to be invoked directly.

| Skill             | Used By   | Description                            |
| ----------------- | --------- | -------------------------------------- |
| `analyze-changes` | `/commit` | Analyzes git tree for commit groupings |
| `version-bump`    | `/commit` | Bumps version and updates changelog    |

### Scripts

| Script                     | Description                                                                |
| -------------------------- | -------------------------------------------------------------------------- |
| `scripts/install.sh`       | Clone repo, symlink skills, configure permissions, provision Slack webhook |
| `scripts/uninstall.sh`     | Remove symlinks and toolkit directory                                      |
| `scripts/clean-install.sh` | Fresh reinstall (remove + install)                                         |
| `scripts/test-install.sh`  | Installation test script for CI/validation                                 |
| `scripts/package-skill.sh` | Package a skill into a single .skill file for Claude Desktop               |

## Updating

From within Claude Code:

```text
/aid-update
```

Or from the command line:

```bash
cd ~/.claude/aidev-toolkit && git pull
```

## Architecture Principles

The `/arch-review` command evaluates a codebase against these architectural principles:

| ID     | Principle                  | Focus                                                 |
| ------ | -------------------------- | ----------------------------------------------------- |
| AP-001 | Security by Default        | Input validation, secrets, auth, injection prevention |
| AP-002 | Observable Systems         | Structured logging, correlation IDs, health endpoints |
| AP-003 | Intentional Error Handling | No silent failures, consistent error responses        |
| AP-004 | Test Critical Paths        | Critical path coverage, testable architecture         |

See `architecture-principles/` for full documentation.

## Clean Install

For a fresh install that removes and reinstalls the toolkit:

```bash
~/.claude/aidev-toolkit/scripts/clean-install.sh
```

This safely removes only aidev-toolkit components (the `~/.claude/aidev-toolkit/` directory and its symlinks). It does **not** touch your `CLAUDE.md`, `settings.json`, or other files.

## Uninstalling

```bash
~/.claude/aidev-toolkit/scripts/uninstall.sh
```

## Version

0.53.1

## Changelog

### Release Notes

#### v0.53.1 (2026-04-22)

- fix(install): prevent credential prompts on new install clone [`0caac95`]

#### v0.53.0 (2026-04-22)

- feat(install): add browser-harness skill to install and fix lint [`9d489fd`]
- feat(specs): add v58 Gmail Morning Digest spec [`54fb15c`]

#### v0.52.4 (2026-04-22)

- fix(publish-dist): prevent docs/docs/ duplication when copying directories [`357c2f8`]
- docs(statusline): update ctx:53% screenshot [`7bdd834`]

#### v0.52.3 (2026-04-22)

- chore(lint): simplify markdownlint config and remove prettier pass [`1a45eda`]
- docs(statusline): replace screenshot with cleaner ctx:53% capture [`d11ea40`]
- docs(statusline): add context window impact explanation and color [`b0ad325`]
- docs(statusline): expand doc — config structure, JSON payload, full command breakdown [`79d6bee`]
- docs(sdd): add Validation Needed status — code done, tests blocked [`5b8431f`]

#### v0.52.2 (2026-04-22)

- chore(specs): sync v52 OAuth auth spec — mark complete, README tasks in sync

#### v0.52.1 (2026-04-21)

- chore(specs): complete v57 install.sh email prompt spec verification

#### v0.52.0 (2026-04-21)

- feat(version-bump): add Xcode Info.plist variable detection and fix [`0c4b9bc`]
- feat(install): interactive email prompt for spec ownership [`dc337a4`]
- docs(sdd-template): add two-file model checkbox convention note [`e8fc2ac`]

#### v0.51.1 (2026-04-21)

- fix(aid-feedback): use GitHub user identity for ingestion gate [`051aad1`]

#### v0.51.0 (2026-04-21)

- feat(v55): security-first SDD — mandatory AuthZ/N and audit logging in every spec [`34744ba`]
- feat(v55): add Security-First SDD spec — AuthZ/N and audit logging baked into every spec [`3506632`]

#### v0.50.1 (2026-04-21)

- feat: add /dist-publish project command for aidev-toolkit-dist publishing [`86f6a6d`]

#### v0.50.0 (2026-04-21)

- feat(auth): complete v52 Phase 4–5 — install hint, aid-help auth docs, logout verified [`0e611a1`]

#### v0.49.5 (2026-04-20)

- fix(specs-parse): sort status output numerically instead of lexicographically [`40f7a5b`]

#### v0.49.4 (2026-04-20)

- docs(specs): mark v54 complete — numeric version sort verified [`4f695d3`]

#### v0.49.3 (2026-04-20)

- fix(sdd-code-spec): remove disable-model-invocation to allow skill chaining [`8e8b37f`]

#### v0.49.2 (2026-04-20)

- fix(sdd): use sort -V in specs-parse.sh for correct spec version ordering [`717c6bd`]
- fix(aid-feedback): bootstrap required labels before issue create or ingest [`d8ea5a5`]
- feat(specs): add v54 — specs-parse.sh numeric version sort [`d90924f`]

#### v0.49.1 (2026-04-19)

- docs: add AWS costs report for 2026-04-19 [`1f8c2c9`]

#### v0.49.0 (2026-04-19)

- feat: add /browser-harness skill for direct Chrome CDP control [`c30a5d3`]
- feat(aws-costs): enrich active resources with Project/Environment/Owner tags [`003aedc`]

#### v0.48.0 (2026-04-18)

- feat(v52): GitHub OAuth auth — Cloudflare Worker, auth.sh CLI, JWT identity in user-email.sh [`8342a82`]
- style: markdownlint/prettier bulk reformat across all docs and skills [`92ce955`]

#### v0.47.0 (2026-04-18)

- feat: add /aws-costs skill — spend by service, daily trend, active resources, multi-profile [`16e1bcd`]

#### v0.46.0 (2026-04-18)

- feat: repo cleanup — remove dead Slack pipeline, stale dist/, personal files, scrub HSL refs [`fd52ced`]
- feat: add /remember skill — register in installer, --user/--project flags, help entry [`99aaab5`]
- feat: enhance /docs-update --deep — spec cross-reference, tech stack & path verification [`b6de1dd`]

#### v0.45.4 (2026-04-18)

- feat: add pre-pull guard to /commit-push — silent skip on unstaged changes [`45b2996`]
- feat: add prettier prose-wrap pass and re-enable MD013 in /lint [`45b2996`]
- feat: scope Bash allowed-tools across 10 SDD skills; add allowed-tools-guide.md [`45b2996`]

#### v0.45.3 (2026-04-18)

- docs: mark specs v28 and v43 complete — sdd-spec-status and sdd-init validation done [`ac13786`]
- docs: add specs v49-v51 — monetization, memory confidence tags, memory relationship index [`8619789`]

### 0.5.0

- Initial project setup from PRD.md
- Add CLAUDE.md for Claude Code guidance

---

Copyright (c) 2025 Parallax Intelligence LLC. All rights reserved.
