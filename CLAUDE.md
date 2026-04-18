# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

aidev-toolkit is a collection of AI-enabled SDLC tools for AI developers. It provides:

- **Claude Code skills** for standardized development workflows
- **Architecture principles** that all aidev toolkit projects should follow
- **One-line installer** for easy setup

## Key Concepts

### Skills

Skills are markdown files in `skills/` that Claude Code executes as slash commands. Each skill:

- Uses YAML frontmatter for metadata (name, description, allowed-tools)
- Contains instructions Claude follows when the command is invoked
- Is symlinked to both `~/.claude/commands/` and `~/.claude/skills/` during installation

To create a new skill, use `skills/SKILL-TEMPLATE.md` as reference.

### Modules

The `modules/` directory holds self-contained skill groups. Each module has its own `scripts/`, `templates/`, and `skills/` subdirectories. Module skills are symlinked alongside core skills during installation.

**Current modules:**

- `modules/sdd/` — Spec-Driven Development (9 skills, parse script, spec template)

**Adding a module skill:**

1. Create `modules/{module}/skills/{module}-{name}.md`
2. Add to the module's skills array in `scripts/install.sh` (e.g., `SDD_SKILLS`)
3. Add help entry in `docs/aid-help.md`
4. Run install script to create symlink

### Architecture Principles

Located in `architecture-principles/`. Each uses YAML frontmatter with:

- `id`: AP-XXX identifier
- `severity`: required/recommended
- `category`: security/observability/error-handling/testing

Used by `/arch-review` to validate codebases.

## Development Workflow

### Testing Skill Changes

```bash
# Run install to update symlinks
./scripts/install.sh

# Test in Claude Code
claude
/aid
```

### Adding a New Skill

1. Create `skills/your-skill.md` following SKILL-TEMPLATE.md
2. Add to the `SKILLS` array in `scripts/install.sh`
3. Add help entry in `skills/aid.md`
4. Run install script to create symlink

### Version Management

Version is tracked in two places - keep them in sync:

- `README.md` under `## Version` (primary, with changelog)
- `VERSION` file (single line, used by scripts)

Update both when bumping versions.

## Rules

- **Always use `/commit-push`** for syncing local changes with remote (smart commit + push workflow).
- **Always use `/aid-update`** to update `~/.claude/skills` and `~/.claude/commands` after making changes to skills or scripts — unless explicitly instructed otherwise.

## File Purposes

| File                          | Purpose                                                         |
| ----------------------------- | --------------------------------------------------------------- |
| `scripts/install.sh`          | Clones repo, symlinks skills, configures permissions            |
| `scripts/uninstall.sh`        | Removes symlinks and toolkit directory                          |
| `scripts/clean-install.sh`    | Fresh reinstall                                                 |
| `scripts/test-install.sh`     | Installation test script for CI/validation                      |
| `scripts/package-skill.sh`    | Package a skill into a single .skill file for Claude Desktop    |
| `skills/SKILL-TEMPLATE.md`    | Reference for creating new skills                               |
| `templates/deal-desk/`        | Output templates for /deal-desk skill                           |
| `templates/markdownlint.json` | Default config for /lint skill                                  |
| `modules/sdd/`                | Spec-Driven Development module (skills, parse script, template) |

## Development Methodology

### Definition of Done

A task is NOT complete until it has been validated through testing:

1. **Unit tests** - For utility functions, parsers, data transformations
2. **Integration tests** - For database operations, API calls, cross-component flows
3. **Manual verification** - For UI changes, CLI tools, end-to-end workflows

If tests don't exist, create them. If dependencies aren't configured (e.g., database connection), flag the task as **blocked** rather than complete.

### Planning Requirements

When creating specs or plans, include:

- [ ] **Test criteria** - How will we verify this works?
- [ ] **Dependencies** - What needs to be configured/available?
- [ ] **Validation steps** - Manual or automated verification

### Task States

- **Pending** - Not started
- **In Progress** - Being worked on
- **Blocked** - Cannot complete (missing dependency, config, etc.)
- **Complete** - Implemented AND validated through testing
