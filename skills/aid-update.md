---
name: aid-update
tier: core
description: Pull latest aidev toolkit updates from GitHub
allowed-tools:
  - "Read(~/.claude/aidev-toolkit/**)"
  - "Bash(cat ~/.claude/aidev-toolkit/*)"
  - "Bash(git -C ~/.claude/aidev-toolkit pull)"
  - "Bash(git -C ~/.claude/aidev-toolkit log*)"
  - "Bash(~/.claude/aidev-toolkit/scripts/aid-changelog.sh*)"
  - "Bash(~/.claude/aidev-toolkit/scripts/install.sh*)"
  - "Bash(ln -sf ~/.claude/aidev-toolkit/skills/*.md ~/.claude/commands/)"
  - "Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh*)"
model: haiku
---

# aidev toolkit Update

You are updating the aidev toolkit. Execute these steps without asking for permission.

## Instructions

1. Read the current version from `~/.claude/aidev-toolkit/VERSION` and remember it as `OLD_VERSION`
2. Pull latest changes:

```bash
git -C ~/.claude/aidev-toolkit pull
```

1. Run the installer:

```bash
~/.claude/aidev-toolkit/scripts/install.sh --quiet
```

1. Read the new version from `~/.claude/aidev-toolkit/VERSION`
2. Check email configuration (prompt if not set):

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh ensure
```

1. Display the result based on what happened:

### If updates were pulled

```text
aidev toolkit Update
==================

Pulling latest from GitHub...

Updated to v{NEW_VERSION} (was v{OLD_VERSION}).

What's new:

2026-10-19  v0.105.4
  - fix: sdd-code checks task boxes immediately so progress survives restarts
  - docs: add specs v120-v124 to README and spec files

2026-10-18  v0.105.3
  - chore: untrack gchat bytecode

All skills reinstalled.
```

To build the "What's new" section, run the changelog script with the version you
recorded before the pull. It reads the release notes in the toolkit README and
prints each release newer than `OLD_VERSION` as `<date>  <version>` followed by
a bullet per change (no commit hashes, no version-bump/publish bookkeeping):

```bash
~/.claude/aidev-toolkit/scripts/aid-changelog.sh {OLD_VERSION}
```

Print its output verbatim under "What's new:". Do NOT use `git log` for this —
the installed repo only holds `chore: publish vX` commits, which say nothing
about what changed. If the script prints nothing, omit the section.

### If already up to date

```text
aidev toolkit Update
==================

Already up to date (v{VERSION}).
```

### If there's an error

Explain the error and suggest:

```text
To reinstall from scratch:
  rm -rf ~/.claude/aidev-toolkit
  gh repo clone vacobuilt/aidev-toolkit ~/.claude/aidev-toolkit
  ~/.claude/aidev-toolkit/scripts/install.sh
```
