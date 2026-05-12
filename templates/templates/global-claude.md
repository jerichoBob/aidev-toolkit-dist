# Global Claude Code Instructions

This file provides guidance to Claude Code across all projects.

## About You

Edit this section to describe your role, goals, and preferences:

- Your name and title
- Your domain expertise
- Your preferred collaboration style
- Any standing preferences (language, framework preferences, etc.)

---

## CRITICAL RULES

### NO EPHEMERAL SCRIPTS OR DATA — EVER

Every script and dataset produced in response to a user prompt is a user work product. The user paid for it with tokens and has the right to see it, reuse it, modify it, and build on it. Never create throwaway scripts inline or let generated data disappear into a temp file.

**Scripts** → write to `<project>/.claude/scripts/` (or a project-visible equivalent) **before** running them.

**Datasets / output files** → write to `<project>/.claude/data/` (or another project-visible location) immediately.

If no project directory exists yet, use `~/.claude/scripts/` or `~/.claude/data/` as a fallback.

**Rule: if Claude produced it, the user can find it.**

### NO MOCKS — EVER

**NEVER use mocks in tests.** No `vi.mock`, no `jest.mock`, no sinon stubs, no mock implementations. They hide bugs, are fragile, and waste time debugging the mock instead of the code. Use real implementations, test fixtures, in-memory databases, actual CLI calls, or integration tests instead. If a dependency isn't available (e.g., no API key, no d2 CLI), skip the test or mark it as **blocked** — don't fake it with mocks.

---

## Uncertainty & Tradeoffs

- Don't assume. Don't hide confusion. Surface tradeoffs.
- When a request has multiple valid interpretations, state them explicitly and ask for clarification rather than picking one silently.
- Before starting a non-trivial task, state your assumptions so the user can redirect early.

---

## Development Methodology

### Definition of Done

A task is NOT complete until it has been validated through testing:

1. **Unit tests** - For utility functions, parsers, data transformations
2. **Integration tests** - For database operations, API calls, cross-component flows
3. **Manual verification** - For UI changes, CLI tools, end-to-end workflows

If tests don't exist, create them. If dependencies aren't configured, flag the task as **blocked** rather than complete.

---

## Project-Specific Customization

Edit the sections below for each project:

### About This Project

Brief overview of what the project does, its architecture, and key files.

### Key Rules for This Project

Project-specific constraints, patterns, or conventions that go beyond the global rules above.

### Testing Strategy

How tests are run, where they live, what coverage is expected.

### Deployment & Release

How code gets deployed, versioning strategy, release process.

---

## Development Workflow

### When to Ask for Clarification

- If a request is ambiguous, list the valid interpretations and ask the user to pick
- If scope is unclear (is this a one-liner or a refactor?), ask before starting
- If there are tradeoffs, explain them and get the user's choice

### When NOT to Ask

- You have clear context from prior conversation
- The request is simple and one interpretation is obvious
- Asking would slow down routine work (typo fixes, small edits)

### Debugging Approach

- Read the error message thoroughly
- Look at the surrounding code and tests first
- Check recent git history for clues about what changed
- Create a minimal reproduction if possible

---

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| YYYY-MM-DD | Initial setup |
