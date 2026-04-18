---
name: version-bump
description: Supporting skill for /commit. Bumps version and changelog.
allowed-tools: Read, Edit, Write, Bash(git:*)
user-invocable: true
model: inherit
---

# Version Bump Skill

Increment semantic version number and update changelog with commit entries.

**Note:** This is a support skill primarily called by `/commit` and `/commit-push`. It can be called directly for debugging, but is typically used as a sub-skill.

## Arguments

- **bump_type** (required): `major`, `minor`, or `patch`
- **commits** (required): List of commits to include in release notes, each with:
  - `hash`: Short commit hash (7 chars)
  - `type`: Commit type (feat, fix, docs, etc.)
  - `summary`: Commit message summary
- **version_override** (optional): Explicit version like `X.Y.Z` to use instead of incrementing

## Instructions

### 1. Detect Version File

Check in order, use first that exists:

1. `package.json` - Node.js projects (look for `"version": "X.Y.Z"`)
2. `manifest.json` - Chrome extensions (look for `"version": "X.Y.Z"`)
3. `CHANGELOG.md` - Standalone changelog
4. `README.md` - Final fallback (changelog section at end)

**If no version found anywhere:** Add a `## Changelog` section to `README.md` with initial version:

```markdown
---

## Changelog

0.0.0

### Release Notes
```

### 2. Read Current Version

Extract the current version string (e.g., `1.2.3`).

### 3. Validate Changelog vs Git Log

Before bumping, check that the changelog is in sync with git:

```bash
# Find last version bump commit
git log --oneline --grep="^chore: bump version" -1

# Get commits since then (excluding the bump itself)
git log --oneline <last_bump_hash>..HEAD
```

**Compare:** The commits listed in the current version's release notes should match the git log since the last bump.

If mismatch detected:

- WARN the user
- List missing commits
- Ask if they want to proceed or fix first

### 4. Calculate New Version

If `version_override` provided, use that directly.

Otherwise, increment based on `bump_type`:

| bump_type | Current | New   |
| --------- | ------- | ----- |
| `major`   | 1.2.3   | 2.0.0 |
| `minor`   | 1.2.3   | 1.3.0 |
| `patch`   | 1.2.3   | 1.2.4 |

### 5. Update Version File

**For package.json:**

```json
{
  "version": "X.Y.Z"
}
```

**For manifest.json:**

```json
{
  "version": "X.Y.Z"
}
```

**For CHANGELOG.md or README.md changelog section:**
Replace the version line:

```markdown
## Changelog

X.Y.Z
```

### 6. Update Release Notes (ALWAYS)

Changelog entries are **mandatory**. Determine the changelog location:

1. If `CHANGELOG.md` exists -> use it
2. Otherwise -> use `README.md` (create `## Changelog` section at end if missing)

Prepend new release section after `### Release Notes` (or `## Release Notes`):

```markdown
#### vX.Y.Z (YYYY-MM-DD)

- type: Summary [`hash`]
- type: Summary [`hash`]
```

**Format each commit as:**

```text
- <type>: <summary> [`<short_hash>`]
```

Example in README.md:

```markdown
---

## Changelog

0.7.0

### Release Notes

#### v0.7.0 (2026-01-22)

- feat: Add user dashboard [`abc1234`]
- docs: Update API documentation [`def5678`]
- fix: Handle null pointer in auth [`ghi9012`]
```

### 7. Stage Files

```bash
git add README.md         # always (changelog lives here by default)
git add CHANGELOG.md      # if it exists and was used
git add package.json      # if it exists and was updated
git add manifest.json     # if it exists and was updated
```

### 8. Return Result

Report:

- Previous version
- New version
- Commits included (with hashes)
- Files staged

## Output Format

```text
Version bumped: 1.2.3 -> 1.3.0 (minor)

Commits in this release:
  - feat: Add user dashboard [`abc1234`]
  - docs: Update API docs [`def5678`]

Files staged:
  - README.md (changelog updated)
  - package.json
```

## Validation Errors

If changelog doesn't match git log:

```text
Warning: Changelog out of sync with git log!

Missing from changelog:
  - abc1234 docs: Add Asmark On Demand analysis

Extra in changelog (not in git):
  - (none)

Fix changelog before proceeding, or use --force to skip validation.
```
