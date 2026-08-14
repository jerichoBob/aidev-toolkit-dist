# Codebase Overview: aidev-toolkit

> Generated via `/inspect`. Update this file when the project's structure changes significantly — it's linked from `/aid`'s help output as the canonical "what is this thing" reference.

## Identity

- **Description**: AI-powered slash commands & skills for Claude Code that automate SDLC tasks — commits, spec-driven development, code review, and more.
- **Repository**: `git@github.com:jerichoBob/aidev-toolkit.git` (this is the source repo; a companion public repo `jerichoBob/aidev-toolkit-dist` is the distribution target users actually clone/install from)
- **Version**: 0.89.0 (tracked in `VERSION` and `README.md` — keep both in sync)
- **Stack**: Bash + Markdown (no compiled language, no package manifest) — Claude Code itself is the runtime; skills are prompt instructions, not executable code

## Architecture Overview

Not a traditional application — it's a plugin/distribution system for Claude Code. Two layers:

- `skills/` (29 files) — top-level, always-installed slash commands (`/commit`, `/inspect`, `/arch-review`, etc.), each a markdown file with YAML frontmatter (`name`, `description`, `allowed-tools`)
- `modules/sdd/` — a self-contained skill group (Spec-Driven Development): its own `skills/`, `scripts/`, `templates/` subdirectories, copied alongside core skills at install time

Entry point: `scripts/install.sh` → copies (not symlinks, since spec-v99) skill files into `~/.claude/commands/` and `~/.claude/skills/`, so any Claude Code session picks them up as slash commands.

Key directories:

- `skills/` — core skill definitions
- `modules/sdd/` — spec-driven dev workflow (parse script, spec/onboarding templates)
- `architecture-principles/` — 7 numbered principles (AP-001–AP-007: security, observability, error handling, testing, security-first SDD, supply chain integrity, runtime-adjustable observability), enforced via `/arch-review`
- `scripts/` — shared shell utilities (install/uninstall, auth, screenshots, statusline, usage logging)
- `specs/` — this project's own spec-driven backlog (100+ specs tracked in `specs/README.md`)
- `tests/` — dozens of test scripts, run via `tests/run-all.sh`
- `docs/` — help reference (`aid-help.md`), auth/security docs
- `.aid/` — arch-review output and local config

## Tech Stack

- **Runtime**: Claude Code CLI (the actual "execution environment" for skills)
- **Framework**: none — plain bash scripts + markdown instruction files
- **Database**: none
- **External Services**: GitHub CLI (`gh`) for issue/PR operations and the dist-repo publish flow; optionally AWS Bedrock (routing via `settings.json` env vars) instead of direct Anthropic API

## Development Workflow

    ~/.claude/aidev-toolkit/scripts/install.sh   # Install/update the toolkit locally
    ./tests/run-all.sh                            # Run the full test suite
    /commit-push                                  # This repo's own convention for shipping changes

Environment: `.env.example` documents two optional overrides (`AIDEV_SCREENSHOTS_DIR`, `AIDEV_SCREENSHOTS_PATTERN`) — most users need no `.env` at all.

## Code Conventions

- Skills are markdown instruction files, not code — each has YAML frontmatter (`name`, `description`, `allowed-tools`, sometimes `tier: core|extended`)
- Spec-driven development is dogfooded on itself: this repo's own `specs/README.md` is the single source of truth for task tracking (checkboxes only ever live there, never in individual `spec-v*.md` files — enforced convention, not tooling-enforced)
- `CLAUDE.md` mandates: no mocks in tests ever, no ephemeral scripts (persist to `.claude/scripts/`), markdownlint on every `.md` write, never touch `~/.claude/` directly (it's a deploy target, not source)

## Domain Context

Solves the "every new project needs the same SDLC scaffolding" problem for Claude Code users: rather than re-explaining commit conventions, spec tracking, or architecture review rules per-project, this toolkit ships them as reusable slash commands installed once globally and invoked from any repo.

Key entities:

- **Skill**: a markdown-defined slash command (e.g. `/commit`, `/sdd-spec`)
- **Spec**: a versioned unit of tracked work (`specs/spec-vN-*.md` + a checklist entry in `specs/README.md`)
- **Architecture Principle (AP-NNN)**: a codified, checkable standard (security, observability, etc.) validated by `/arch-review`
- **Module**: a self-contained skill group with its own scripts/templates (currently just `sdd`)
