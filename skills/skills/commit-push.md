---
name: commit-push
description: Same as /commit but auto-pushes after completion.
argument-hint: [version]
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(git:*), Bash(gh:*), AskUserQuestion
model: inherit
---

# Smart Commit & Push

Runs `/commit` workflow and then automatically pushes.

## Arguments

- **Optional version**: `X.Y.Z` format (e.g., `3.6.1`) to use exact version instead of auto-calculating
- **--verbose**: Show detailed output including narration and intermediate results

## Output Style

**Default: Minimal task-level output.** No narration ("Let me...", "Now I'll..."), just progress:

```text
Pulling... OK
Analyzing...

=== CHANGES ===
Type: docs (patch)
Summary: Update API documentation

Committing... OK
Bumping 1.2.3 → 1.2.4... OK
Pushing... OK

Done! Version 1.2.4 pushed.
```

**With --verbose:** Include narration, intermediate results, and tool output details.

## Instructions

1. **Pre-pull check — detect unstaged changes before pulling:**

   ```bash
   git diff --quiet && git diff --cached --quiet
   ```

   - **If the command exits non-zero** (changes exist): skip `git pull` entirely. Log one line: `Skipping pull — unstaged changes present.`
   - **If the command exits zero** (clean tree): proceed with `git pull` normally as part of the commit workflow.

   Then always run a divergence check regardless of whether pull was skipped:

   ```bash
   git fetch origin 2>/dev/null
   git status -sb
   ```

   If the status shows `behind`, warn: `Warning: remote has new commits — push may require a merge.`

2. **Execute the full `/commit` workflow** (steps 1-6, skipping the pull step if already handled above):
   - Pull latest (skip if pre-pull check detected changes)
   - Analyze changes (using `analyze-changes` skill)
   - Commit each group
   - Bump version (using `version-bump` skill)
   - Update changelog (CHANGELOG.md if exists, otherwise README.md)
   - Commit version bump
   - Verify clean state

2. **Automatically push** (do not ask):

   a. Check authentication:

   ```bash
   gh auth status 2>&1
   ```

   If `gh` is not authenticated, stop and instruct user to run `gh auth login`.

   b. Check if a remote is configured:

   ```bash
   git remote get-url origin 2>/dev/null
   ```

   c. **If no remote configured** (command returned nothing or error):
      - Check if the remote URL would be GitHub (ask user to confirm)
      - Ask for org/account using `AskUserQuestion`: "No remote configured. Create a new GitHub repo and push? Choose an account/org:" — list orgs from `gh auth status`
      - Ask for visibility: "Public or private?"
      - Run:

        ```bash
        gh repo create {name} --{visibility} --source . --remote origin --push
        ```

      - Report: "Created {org}/{name} on GitHub and pushed."

   d. **If remote is configured** (check if it's GitHub):
      - If remote URL contains `github.com`: push normally with `git push`
      - If remote URL does not contain `github.com` (non-GitHub remote): push with `git push` (skip `gh`)

3. **Report completion** (see Output Style above)

## Difference from /commit

| Command | Version Bump | Changelog | Push |
|---------|--------------|-----------|------|
| `/commit` | Always | Always (README.md default) | Asks first |
| `/commit-push` | Always | Always (README.md default) | Automatic |

See `/commit` for full documentation on grouping, versioning, and release notes.

## Example Output

**Default (minimal):**

```text
Pulling... OK
Analyzing...

=== CHANGES ===
Type: docs (patch)
Summary: Update API documentation

Committing... OK
Bumping 1.2.3 → 1.2.4... OK
Pushing... OK

Done! Version 1.2.4 pushed.
```

**With --verbose:**

```text
Pulling latest... OK
Analyzing changes... OK

=== CHANGE ANALYSIS ===
Overall version bump: patch

--- Group 1 of 1 ---
Type: docs
Summary: Update API documentation

Committing... OK
[main abc1234] docs: Update API documentation

Bumping version 1.2.3 -> 1.2.4 (patch)... OK
Updating changelog in README.md... OK
[main def5678] chore: bump version to 1.2.4

Pushing... OK
To github.com:user/repo.git
   old1234..def5678  main -> main

Done! Version 1.2.4 pushed.
```
