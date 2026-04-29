# aidev-toolkit

**AI-powered slash commands & skills for Claude Code that handle the tedious parts of software development — commits, specs, code review, and more.**

Built for developers who use [Claude Code](https://claude.ai/code) and want a consistent, automated SDLC workflow across all their projects.

```bash
gh repo clone jerichoBob/aidev-toolkit-dist ~/.claude/aidev-toolkit && ~/.claude/aidev-toolkit/scripts/install.sh
```

Then open any project in Claude Code and run `/aid` to see what's available.

---

## What You Can Do

**Smart commits in one command**

Instead of manually staging, writing commit messages, bumping versions, and pushing:

```text
/commit-push
```

It analyzes your changes, groups them into logical commits, writes conventional commit messages, bumps the version, updates the changelog, and pushes — all without you writing a single commit message.

**Spec-driven development**

Describe a feature, get a full implementation plan with phases and tasks:

```text
/sdd-spec "add OAuth login with GitHub"
/sdd-code-spec v5
```

Claude creates the spec, then implements it phase by phase with a living checklist in `specs/README.md`. You always know what's done, what's next, and why decisions were made.

**Instant codebase orientation**

Drop into an unfamiliar repo and get oriented in 30 seconds:

```text
/inspect
```

Returns architecture, tech stack, entry points, patterns, and anything you'd want to know before making changes.

**Architecture review**

Check your codebase against security, observability, error handling, and testing principles:

```text
/arch-review
```

Flags issues against documented principles with severity levels and remediation suggestions.

**Gmail triage**

Scrape your inbox and categorize unread emails by urgency — without leaving Claude Code:

```text
/gmail-digest
```

---

## Install

**Requirements:** [Claude Code](https://claude.ai/code), [GitHub CLI](https://cli.github.com/), `git`, `jq`

```bash
# Recommended
gh repo clone jerichoBob/aidev-toolkit-dist ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh
```

<details>
<summary>Other install methods</summary>

```bash
# SSH
git clone git@github.com:jerichoBob/aidev-toolkit-dist.git ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh

# HTTPS
git clone https://github.com/jerichoBob/aidev-toolkit-dist.git ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh
```

</details>

The installer symlinks skills to `~/.claude/commands/` and `~/.claude/skills/` so they're available as slash commands in every Claude Code session.

**To update:**

```text
/aid-update
```

---

## Skills

Skills are organized into two tiers: **core** (daily drivers, shown by default in `/aid`) and **extended** (powerful when needed, available via `/aid --all`).

### Dev Workflow

| Command         | What it does                                                    |
| --------------- | --------------------------------------------------------------- |
| `/commit`       | Group changes, write conventional commit messages, bump version |
| `/commit-push`  | Same as `/commit` plus auto-push, tests, and dist publish       |
| `/lint`         | Lint and auto-fix markdown files                                |
| `/gmail-digest` | Scrape Gmail inbox and categorize unread emails by urgency      |
| `/remember`     | Save a note to persistent memory (project or user scope)        |

### Analysis & Review

| Command        | What it does                                                              |
| -------------- | ------------------------------------------------------------------------- |
| `/inspect`     | Analyze any codebase — identity, architecture, tech stack, patterns       |
| `/arch-review` | Validate codebase against security, observability, and testing principles |

### Spec-Driven Development (SDD)

A full workflow for writing specs before code, tracking implementation phase by phase.

| Command          | What it does                                            |
| ---------------- | ------------------------------------------------------- |
| `/sdd-spec`      | Create a new specification document from a description  |
| `/sdd-specs`     | Show all specs — status, staleness, progress summary    |
| `/sdd-code`      | Implement the next single task                          |
| `/sdd-code-spec` | Implement all remaining tasks in a spec end-to-end      |
| `/sdd-init`      | Scaffold a `specs/` directory for a new project         |

### Toolkit Management

| Command         | What it does                        |
| --------------- | ----------------------------------- |
| `/aid`          | Show core commands (daily drivers)  |
| `/aid-update`   | Pull latest updates from GitHub     |
| `/aid-feedback` | Submit feedback or feature requests |

<details>
<summary>Extended skills — available but not shown by default</summary>

Run `/aid --all` to see these in the terminal.

#### Dev Workflow

| Command              | What it does                                                              |
| -------------------- | ------------------------------------------------------------------------- |
| `/test-run`          | Run the full test suite, save a timestamped report                        |
| `/test-status`       | Show results table from the last test run                                 |
| `/code-stats`        | Count lines of code by language                                           |
| `/should-i-trust-it` | Verify a skill file for malicious patterns before installing              |
| `/browser-harness`   | Direct Chrome CDP control — install, connect, and run browser tasks       |
| `/screenshots`       | Load recent macOS screenshots into Claude's context                       |
| `/aws-costs`         | Show AWS spend by service, daily trend, and active resources              |
| `/status-footer`     | Configure the Claude Code status line (dir, branch, ctx%, etc.)           |
| `/analyze-changes`   | Analyze git changes and determine version bump type (support skill)       |
| `/version-bump`      | Bump version and update changelog (support skill)                         |

#### Analysis & Planning

| Command      | What it does                                                       |
| ------------ | ------------------------------------------------------------------ |
| `/deal-desk` | Deal qualification and risk assessment from project documents      |
| `/sdlc-plan` | Parse RFQ/RFP/PRD/SOW documents into a phased implementation plan |

#### Spec-Driven Development (SDD)

| Command               | What it does                                                    |
| --------------------- | --------------------------------------------------------------- |
| `/sdd-next`           | Show the next unimplemented task across all specs               |
| `/sdd-next-phase`     | Show all tasks in the current phase                             |
| `/sdd-code-phase`     | Implement all tasks in the current phase                        |
| `/sdd-spec-prioritize`| Recommend top N specs to focus on next                          |
| `/sdd-spec-status`    | Show phase-by-phase progress for a specific spec                |
| `/sdd-spec-owner`     | Set or unset spec owner                                         |
| `/sdd-spec-tagging`   | Commit tagging convention reference                             |
| `/sdd-specs-archive`  | Move completed specs to specs/completed/ to declutter           |
| `/sdd-specs-doctor`   | Migrate spec files to YAML frontmatter format                   |
| `/sdd-specs-update`   | Sync project with SDD infrastructure                            |

#### Toolkit Management

| Command         | What it does                             |
| --------------- | ---------------------------------------- |
| `/aid-login`    | Authenticate via browser-based GitHub OAuth |
| `/docs-update`  | Update README.md and CLAUDE.md           |

</details>

---

## How It Works

Skills are markdown files. Each file contains frontmatter (name, description, allowed tools) and a set of instructions Claude follows when you invoke the command.

```text
~/.claude/
├── commands/
│   ├── commit.md -> ../aidev-toolkit/skills/commit.md
│   ├── inspect.md -> ../aidev-toolkit/skills/inspect.md
│   └── ...
└── aidev-toolkit/          ← git clone of this repo
    ├── skills/             ← core skill files
    └── modules/sdd/        ← Spec-Driven Development module
```

Because skills are just text files, they're readable, forkable, and customizable. You can modify any skill to change how it behaves, or create new ones. The `install.sh` script symlinks them so updates via `/aid-update` propagate instantly.

---

## Architecture Principles

The `/arch-review` command evaluates codebases against these principles:

| ID     | Principle                  | Focus                                                  |
| ------ | -------------------------- | ------------------------------------------------------ |
| AP-001 | Security by Default        | Input validation, secrets, auth, injection prevention  |
| AP-002 | Observable Systems         | Structured logging, correlation IDs, health endpoints  |
| AP-003 | Intentional Error Handling | No silent failures, consistent error responses         |
| AP-004 | Test Critical Paths        | Critical path coverage, testable architecture          |

Full definitions in `architecture-principles/`.

---

## Clean Install / Uninstall

```bash
# Fresh reinstall (removes and reinstalls toolkit only — leaves CLAUDE.md, settings.json untouched)
~/.claude/aidev-toolkit/scripts/clean-install.sh

# Remove toolkit
~/.claude/aidev-toolkit/scripts/uninstall.sh
```

---

## Version

0.68.0

## Changelog

### Release Notes

#### v0.68.0 (2026-04-29)

- feat(skill-tiers): implement v65 — tier field, /aid core/extended view, README restructure [`e290773`]

#### v0.67.2 (2026-04-29)

- fix(gmail-digest): complete v58 — fix stale daemon, correct arch docs [`4679105`]

#### v0.67.1 (2026-04-29)

- docs(specs): add v66 /miro — CRUD Miro diagrams from Claude Code [`b683a81`]
- feat(gmail-digest): use dedicated Chrome on port 19512 for CDP [`9b2d6fd`]

#### v0.67.0 (2026-04-26)

- feat(specs): add v64 Developer Amplifier and v65 Skill Tiers specs [`55f91f2`]
- docs(specs): add v64 and v65 entries and task checklists to specs/README.md [`877a3de`]
- chore: add VS Code multi-root workspace file [`af7c815`]
- docs(readme): update tagline to mention skills alongside slash commands [`338d81e`]
- fix(readme): add language specifiers to fenced code blocks (MD040) [`96cec79`]

#### v0.66.0 (2026-04-26)

- feat(install): add markdownlint auto-fix PostToolUse hook for all users [`c5c6285`]

#### v0.65.2 (2026-04-26)

- fix(sdd-specs): replace misleading completion % with actionable spec/task counts [`6f6fe12`]

#### v0.65.1 (2026-04-26)

- docs(v62): rewrite README with value-first structure and workflow examples [`de9d08a`]
- docs(specs): add v62 readme-overhaul (complete) and v63 windows-support specs [`14a9597`]

#### v0.65.0 (2026-04-24)

- feat(status-footer): add interactive numbered menu for toggling components [`fdb95ae`]

#### v0.64.0 (2026-04-24)

- feat: add /status-footer skill and statusline.sh script [`7ceded9`]
- feat(commit-push): auto-run tests and dist-publish after push [`394d206`]

#### v0.63.1 (2026-04-24)

- fix(gmail-digest): auto-open Chrome inspect page when CDP not reachable [`c47b080`]

#### v0.63.0 (2026-04-24)

- feat: promote gmail-digest, test-run, test-status to toolkit skills [`61177e3`]

#### v0.62.3 (2026-04-24)

- test(v58): remove vestigial ANTHROPIC_API_KEY test — script has no API dependency [`5c4ea6e`]

#### v0.62.2 (2026-04-24)

- fix(v58): gmail-digest — normalize dedup keys to catch whitespace-variant duplicates [`701512f`]

#### v0.62.1 (2026-04-24)

- fix(v58): gmail-digest — post-scrape date filter and deduplication [`0c7121f`]

#### v0.62.0 (2026-04-24)

- feat(v58): gmail-digest --account email@domain — launch dedicated Chrome per profile [`7059dd2`]

#### v0.61.2 (2026-04-24)

- fix(v58): account list reads Chrome Preferences files — shows all profiles instantly [`63acd78`]

#### v0.61.1 (2026-04-24)

- fix(v58): account list stops on first non-inbox page — no email in title = break [`52b6a5c`]

#### v0.61.0 (2026-04-24)

- feat(v58): gmail-digest — --days/--weeks range, --all read+unread, --account N/list [`fc1ed68`]

#### v0.60.3 (2026-04-24)

- refactor(v58): gmail-digest pure scraper — remove anthropic dep, enrich skill output, clean tests [`1eb55dc`]

#### v0.60.2 (2026-04-24)

- fix(v58): /gmail-digest skill needs no API key — scrape via dry-run, categorize inline [`e365525`]

#### v0.60.1 (2026-04-23)

- test(v58): add gmail-digest integration test suite and update spec progress [`72ff9dc`]

#### v0.60.0 (2026-04-23)

- feat(v58): add gmail-digest.py — daily inbox triage via Claude [`a9c3c68`]

#### v0.59.0 (2026-04-23)

- feat(v61): split /test-run and /test-status — persistent timestamped reports [`efaeccc`]

#### v0.58.0 (2026-04-23)

- feat(v60): complete test coverage phase 2 — all remaining scripts [`ec44623`]

#### v0.57.0 (2026-04-23)

- feat(v32): add Xcode Info.plist validation tests; mark spec complete [`cb732b4`]
- feat(specs): add v60 — test coverage phase 2, remaining script tests [`3e43b68`]
- feat(test-status): add Coverage column sourced from test file comments [`963c4b1`]
- feat: add /test-status project skill to run test suite and display results [`cbb9393`]

#### v0.56.0 (2026-04-23)

- feat(v59): integrate test coverage requirement into development methodology [`fda95f8`]
- feat(v59): add complete test suite with full coverage [`272bfee`]

#### v0.55.0 (2026-04-23)

- feat: add /aid-login skill for GitHub OAuth authentication [`b950dff`]

#### v0.54.2 (2026-04-23)

- feat(v52): mark GitHub OAuth auth spec complete [`58dc8ef`]

#### v0.54.1 (2026-04-23)

- docs: fix markdown formatting in docs-update skill [`109df9d`]

#### v0.54.0 (2026-04-22)

- feat(lint): support directory arguments with recursive glob expansion [`e1bd62f`]

#### v0.53.3 (2026-04-22)

- fix(clean-install): require gh CLI, skip auth if already logged in [`94f1ff9`]

#### v0.53.2 (2026-04-22)

- fix(install): require gh CLI, skip auth if already logged in [`6651cce`]
- fix(uninstall): remove invalid stderr redirect in for loop glob [`246d273`]

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
