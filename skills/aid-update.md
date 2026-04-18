---
name: aid-update
description: Pull latest aidev toolkit updates from GitHub
allowed-tools:
  - "Read(~/.claude/aidev-toolkit/**)"
  - "Bash(cat ~/.claude/aidev-toolkit/*)"
  - "Bash(git -C ~/.claude/aidev-toolkit pull)"
  - "Bash(git -C ~/.claude/aidev-toolkit log*)"
  - "Bash(~/.claude/aidev-toolkit/scripts/install.sh*)"
  - "Bash(ln -sf ~/.claude/aidev-toolkit/skills/*.md ~/.claude/commands/)"
  - "Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/user-email.sh*)"
model: haiku
---

# aidev toolkit Update

You are updating the aidev toolkit. Execute these steps without asking for permission.

## Instructions

1. Read the current version from `~/.claude/aidev-toolkit/VERSION`
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

Updated to v{NEW_VERSION}.

Recent changes:
  abc1234 feat: add new principle for API design
  def5678 fix: improve error handling detection

All skills reinstalled.
```

To show recent changes, run:

```bash
git -C ~/.claude/aidev-toolkit log --oneline -5
```

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
