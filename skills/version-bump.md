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

#### Xcode Project Detection (run in parallel with version file detection)

Check if this is an Xcode project:

```bash
ls *.xcodeproj 2>/dev/null | head -1
```

If a `.xcodeproj` directory is found, set `IS_XCODE=true` and note the project name. This enables Info.plist processing in Step 5.5 below.

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

### 5.5. Fix Info.plist Hardcoded Versions (Xcode projects only)

**Skip this step if `IS_XCODE` is not set.**

#### Find Info.plist files

Search standard locations:

```bash
find . -name "Info.plist" -not -path "*/build/*" -not -path "*/.git/*" | head -10
```

If none found, warn and skip:

```text
[Xcode] Info.plist not found in standard locations — skipping
```

#### Check each Info.plist for hardcoded values

For each `Info.plist` found, use Python to read and inspect:

```python
import plistlib, sys

with open('path/to/Info.plist', 'rb') as f:
    plist = plistlib.load(f)

short_version = plist.get('CFBundleShortVersionString', '')
bundle_version = plist.get('CFBundleVersion', '')

# Hardcoded if it looks like a version number, not a variable reference
short_is_hardcoded = short_version and not short_version.startswith('$(')
bundle_is_hardcoded = bundle_version and not bundle_version.startswith('$(')
```

If both keys already use `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` (or are absent), skip that file — no-op.

#### Replace hardcoded values

For each hardcoded key, replace with the correct variable reference using Python's `plistlib` (handles both XML and binary formats safely):

```python
import plistlib

with open('path/to/Info.plist', 'rb') as f:
    plist = plistlib.load(f)

changed = []
if short_is_hardcoded:
    plist['CFBundleShortVersionString'] = '$(MARKETING_VERSION)'
    changed.append(f'CFBundleShortVersionString → $(MARKETING_VERSION)')
if bundle_is_hardcoded:
    plist['CFBundleVersion'] = '$(CURRENT_PROJECT_VERSION)'
    changed.append(f'CFBundleVersion → $(CURRENT_PROJECT_VERSION)')

with open('path/to/Info.plist', 'wb') as f:
    plistlib.dump(plist, f)
```

Report after each file fixed:

```text
[Fixed] Info.plist: CFBundleShortVersionString → $(MARKETING_VERSION), CFBundleVersion → $(CURRENT_PROJECT_VERSION)
```

If multiple Info.plist files are found, fix all that have hardcoded values and report each one.

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
git add "*/Info.plist"    # if any Info.plist files were fixed
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
