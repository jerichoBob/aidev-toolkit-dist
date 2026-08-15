# Onboarding a New Contributor to a Claude-Enabled AI-Assisted Project

A generic runbook for bringing a new developer or contributor onto any
software project that uses Claude Code, aidev-toolkit, and spec-driven
development (SDD) as its working method. Fill in the bracketed
`[project-specific]` items for the client/project at hand.

## Setup steps, in dependency order

Steps 1–4 are per-person infrastructure/account provisioning; steps 5–6 are
software installs; steps 7–8 are verification before calling setup done.

### 1. Accounts and access (IT / project lead)

- Repo access (GitHub or equivalent)
- `[project-specific]` access the new person needs: cloud project access,
  VPN, shared drives, credentials for `.env`, client systems
- **Two separate Claude accounts/keys — do not conflate them.** Think of
  these as two independent keys that get provisioned, billed, and rotated
  on their own schedules, not one "Claude access" checkbox:
  1. **Claude Code key** — the AI pair-programmer used to *build* the
     product (write code, run `/commands`, drive SDD). Every contributor
     needs this one, day one.
  2. **Product/runtime Claude key** — the credential the *application
     itself* calls at runtime to power in-app AI features. This is a
     different account, usually a different owner, and often a different
     billing/cost center than the Claude Code key above. Only contributors
     working on the AI-feature code paths in the product need this one —
     most new hires never touch it.
  `[project-specific]`: name who provisions each key, where each one lives
  (e.g. individual developer accounts vs. a shared project-level API key),
  and confirm that rotating/revoking one has no effect on the other.

### 2. Platform check: Windows vs Mac

Worth handling proactively — it's the most common source of first-day
friction:

- **macOS**: works out of the box. Requirements: Claude Code, GitHub CLI
  (`gh`), `git`, `jq`.
- **Windows — WSL2 (recommended)**: `wsl --install` in an admin PowerShell,
  then inside WSL2: `sudo apt-get install -y git jq`, then install `gh`
  (apt repo + `gh auth login`).
- **Windows — Git Bash (secondary, partial support)**: install `jq` and
  `gh` via `winget`. (The installer copies skill files rather than
  symlinking them, so Developer Mode is not required for this step.)
- Some skills are platform-restricted (e.g. macOS-only tools like
  screenshot capture or browser automation) and will cleanly error rather
  than silently fail on the wrong platform — don't assume every skill is
  cross-platform.
- If the new person is on Windows, run `/aid-update` before troubleshooting
  from scratch — aidev-toolkit's Windows/Git-Bash compatibility fixes land
  incrementally and an out-of-date install is a common false alarm.

### 3. Install Claude Code

Per Anthropic's install instructions (claude.ai/code) — not part of
aidev-toolkit.

### 4. Install aidev-toolkit

```bash
gh repo clone jerichoBob/aidev-toolkit-dist ~/.claude/aidev-toolkit
~/.claude/aidev-toolkit/scripts/install.sh
```

Requires `gh`, `git`, `jq` already present (step 2). The installer
symlinks (or copies, on platforms that reject symlinks) skills into
`~/.claude/commands/` and `~/.claude/skills/`. Verify with `/aid` inside
any project.

### 5. Project-level environment setup

Follow the project's own local-setup doc (commonly `docs/development.md`
or a `README.md`). Typically: language runtime + virtualenv/package
manager, `.env` populated from a template with credentials from the
project lead, and any editable-install of shared libraries.

### 6. First orientation command

This step branches depending on whether the project already has a codebase:

- **Existing codebase** (the common onboarding case): `/inspect` is the
  30-second codebase orientation command to run first — identity,
  architecture, tech stack. Running the project's spec-status command (e.g.
  `/sdd-specs status`) is also worth doing early and independent of the AI
  tooling, as a sanity check that the spec-tracking convention is visible
  and understandable on its own.
- **Greenfield project** (no code yet): there's nothing for `/inspect` to
  orient into. Run `/sdd-init` instead to scaffold the `specs/` directory,
  then start with `/sdd-spec <description>` for the first piece of work.

### 7. Verify with a trivial real task

Don't stop at "the install script exited 0." Get one real command in the
actual repo producing a real, sane result — e.g. a spec-status report that
matches what you'd expect — before calling setup complete.

### 8. Domain and process walkthrough

This is the step that actually determines how fast the new person becomes
productive — more than the tooling install does:

1. **Spec/process convention** — how work is tracked in this project
   (checkbox granularity, status states: Pending/In Progress/Blocked/
   Complete), usually documented in a `specs/README.md` or equivalent.
2. **Domain rules** — whatever core logic/business rules govern this
   codebase: `[project-specific]` — point to the design docs or code that
   define them.
3. **Codebase architecture walkthrough** — using the toolset itself
   (`/inspect`, reading the architecture design doc) to build a mental
   model, rather than reading source top-to-bottom unguided.
4. **A safe first deliverable** — something low-risk that forces
   engagement with the design docs and produces something reviewable
   (a diagram, a docs pass, a test suite) before any production-logic
   commit.
5. **A real independent task** — the point at which "tooling works" turns
   into "fully productive": an actual open project question, resolved
   independently and logged wherever the project keeps decision records
   (e.g. `docs/communications/`, a ticket, a design doc).

## Replicating this for the next person

- Do the account/access provisioning and platform check (steps 1–2) a day
  or two *before* the walkthrough session, so the walkthrough isn't
  interrupted by install friction.
- Front-load the domain/process walkthrough (step 8) *before* or
  *alongside* the tooling install, not after — tooling install rarely
  takes more than a day; the domain walkthrough is what determines how
  fast someone becomes productive.
- Give them a low-risk first deliverable (diagram, docs, test suite — not
  production logic) as the first checkpoint, then a real open question as
  the second checkpoint.
- If Windows: use WSL2 unless there's a specific reason to use Git Bash;
  run `/aid-update` immediately after install to pick up the latest
  Windows-compatibility fixes.
- Track onboarding bullets in the project's activity log as they happen
  (format: `- YYYY-MM-DD (name): what happened`) — this is what makes an
  onboarding timeline reconstructable after the fact; without it, this
  history only exists in `git log -p` archaeology.
