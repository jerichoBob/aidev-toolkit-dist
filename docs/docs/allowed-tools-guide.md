# allowed-tools Scoping Guide

Every skill in aidev toolkit must declare the exact tools it uses in `allowed-tools`. Undeclared tools trigger permission prompts on every call — breaking the user experience.

## The Rule

**Never use bare `Bash` without a scope.** Always use a glob pattern that names the specific command or script.

```yaml
# Bad — prompts for every Bash call
allowed-tools: Bash

# Good — approves only git subcommands
allowed-tools: Bash(git:*)
```

## Common Patterns

### Script Calls

For skills that invoke toolkit scripts:

```yaml
allowed-tools: Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*)
```

This covers `specs-parse.sh`, `token-tracker.sh`, and any other script in that directory.

### Git Operations

```yaml
allowed-tools: Bash(git:*)
```

Covers all git subcommands: `git status`, `git log`, `git rev-parse`, etc.

### GitHub CLI

```yaml
allowed-tools: Bash(gh:*)
```

Covers all gh subcommands: `gh auth status`, `gh issue create`, `gh pr create`, etc.

### Date/System Commands

```yaml
allowed-tools: Bash(date:*), Bash(mkdir:*), Bash(cp:*)
```

### Native Tool Substitutions

Prefer native tools over Bash for file operations — they require no permission declarations:

| Operation | Use | Not |
|-----------|-----|-----|
| Read a file | `Read` | `Bash(cat:*)` |
| Search contents | `Grep` | `Bash(grep:*)` |
| Find files | `Glob` | `Bash(find:*)` |
| Edit/replace | `Edit` | `Bash(sed:*)` |
| Write a file | `Write` | `Bash(echo:*)` |

See [native-tool-patterns.md](native-tool-patterns.md) for the full substitution table.

## Full Example

A skill that runs SDD scripts, checks git status, and asks the user a question:

```yaml
---
name: my-sdd-skill
description: Does something with specs
allowed-tools: Read, Edit, Glob, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*), Bash(git:*), AskUserQuestion
---
```

## Checklist When Writing a Skill

1. List every tool call in your skill instructions
2. Add each to `allowed-tools` with the narrowest scope that works
3. Replace `cat`/`grep`/`find`/`sed` instructions with `Read`/`Grep`/`Glob`/`Edit`
4. Test by running the skill — any unexpected prompts = missing declaration
