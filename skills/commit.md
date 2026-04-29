---
name: commit
tier: core
description: Analyze changes, group commits, bump version, update changelog.
argument-hint: [version]
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git:*), Bash(gh:*), AskUserQuestion
model: inherit
---

# Smart Commit

Analyze changes, group them logically, commit each group, bump version, then optionally push.

## Arguments

- **Optional version**: `X.Y.Z` format (e.g., `3.6.1`) to use exact version instead of auto-calculating
- **--verbose**: Show detailed output including narration and intermediate results

## Output Style

**Default: Minimal task-level output.** No narration ("Let me...", "Now I'll..."), just progress:

```text
Pulling... OK
Analyzing...

=== CHANGES ===
Type: feat (minor)
Summary: Add user dashboard

Type: docs (patch)
Summary: Update README

Committing group 1... OK
Committing group 2... OK
Bumping 1.2.3 → 1.3.0... OK

Push to origin? (y/n)
```

**With --verbose:** Include narration, intermediate results, commit hashes, and file lists.

## Instructions

### Step 1: Pull Latest

Check if a remote is configured before pulling:

```bash
git remote get-url origin 2>/dev/null
```

- **If no remote**: skip pull entirely, proceed to Step 2
- **If remote configured**: pull with:

```bash
git pull origin
```

If merge conflicts occur, stop and inform the user.

### Step 2: Analyze Changes

**Execute the `analyze-changes` skill** to review the working tree.

This will output:

- Logical commit groups
- Change type per group (feat, fix, docs, etc.)
- Overall version bump type (major, minor, patch)

If no changes to commit, stop here.

### Step 3: Commit Each Group

**Track commits as you make them.** You'll need the hash, type, and summary for each.

For each group from the analysis, in order:

1. **Stage only that group's files:**

   ```bash
   git add <file1> <file2> ...
   ```

2. **Commit with conventional commit message:**

   ```bash
   git commit -m "$(cat <<'EOF'
   <type>: <summary from analysis>

   <details from analysis as bullet points>

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

3. **Capture the commit hash:**

   ```bash
   git log --oneline -1
   ```

   Record the short hash (7 chars), type, and summary for passing to version-bump.

4. **Continue to next group**

### Step 4: Bump Version

**Execute the `version-bump` skill** with:

- `bump_type`: The overall bump type from analysis (major/minor/patch)
- `commits`: List of commits from Step 3, each with:
  - `hash`: Short commit hash (7 chars)
  - `type`: Commit type (feat, fix, docs, etc.)
  - `summary`: Commit message summary
- `version_override`: If user provided explicit version argument

This will:

- Validate changelog is in sync with git log
- Update version file (package.json, manifest.json, or in changelog)
- **ALWAYS** update release notes (defaults to README.md if no CHANGELOG.md exists)
- Stage the version files

### Step 5: Commit Version Bump

```bash
git commit -m "chore: bump version to X.Y.Z"
```

### Step 6: Final Verification

```bash
git status                    # Should be clean
git log --oneline -10         # Show new commits
```

### Step 7: Ask to Push

Ask user: "Push to origin? (y/n)"

If yes:

a. Check authentication:

```bash
gh auth status 2>&1
```

If `gh` is not authenticated, stop and instruct user to run `gh auth login`.

b. Check if a remote is configured:

```bash
git remote get-url origin 2>/dev/null
```

c. **If no remote configured**: - Use `AskUserQuestion` to ask: "No remote configured. Create a new GitHub repo and push? Choose an account/org:" — list orgs from `gh auth status` - Ask for visibility: "Public or private?" - Run: `gh repo create {name} --{visibility} --source . --remote origin --push` - Report: "Created {org}/{name} on GitHub and pushed."

d. **If remote is configured**: - If remote URL contains `github.com`: run `git push` - If non-GitHub remote: run `git push`

---

## Commit Message Format

```text
<type>: <short summary>

<bullet points explaining what changed>

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:**

- `feat:` - New feature (minor bump)
- `fix:` - Bug fix (patch bump)
- `docs:` - Documentation only (patch bump)
- `refactor:` - Code restructuring (patch bump)
- `test:` - Test changes (patch bump)
- `chore:` - Maintenance (patch bump)
- `style:` - Formatting (patch bump)
- `perf:` - Performance (patch bump)
- `feat!:` or `BREAKING CHANGE` - Breaking change (major bump)

---

## Semantic Version Rules

| Highest Type in Batch | Version Bump  |
| --------------------- | ------------- |
| `feat!:` or BREAKING  | Major (X.0.0) |
| `feat:`               | Minor (x.Y.0) |
| Everything else       | Patch (x.y.Z) |

---

## Example Flow

**Default (minimal):**

```text
Pulling... OK
Analyzing...

=== CHANGES ===
Type: feat (minor)
Summary: Add user dashboard

Type: docs (patch)
Summary: Update README

Committing group 1... OK
Committing group 2... OK
Bumping 1.2.3 → 1.3.0... OK

Push to origin? (y/n)
```

**With --verbose:**

```text
Pulling latest... Already up to date.
Analyzing changes...

=== CHANGE ANALYSIS ===
Overall version bump: minor (feat detected)

--- Group 1 of 2 ---
Type: feat
Summary: Add user dashboard
Files: src/Dashboard.tsx, src/hooks/useDashboard.ts

--- Group 2 of 2 ---
Type: docs
Summary: Update README with setup instructions
Files: README.md

Committing group 1...
[main abc1234] feat: Add user dashboard

Committing group 2...
[main def5678] docs: Update README with setup instructions

Bumping version 1.2.3 → 1.3.0 (minor)...
Updating changelog in README.md...
[main ghi9012] chore: bump version to 1.3.0

Push to origin? (y/n)
```

---

## Important

- **Always analyze before committing** - Use the skill, don't skip it
- **Version bump is mandatory** - Never skip step 4
- **Changelog is mandatory** - Always added (to CHANGELOG.md if exists, otherwise README.md)
- **One commit per logical group** - Keep them atomic
- **Version bump commit is always last** - Before push
