---
name: analyze-changes
description: Supporting skill for /commit. Analyzes git tree for groupings.
allowed-tools: Read, Glob, Grep, Bash(git:*)
user-invocable: true
model: inherit
---

# Analyze Changes Skill

Review git working tree and propose logical commit groupings with change types.

**Note:** This is a support skill primarily called by `/commit` and `/commit-push`. It can be called directly for debugging, but is typically used as a sub-skill.

## Arguments

None. Operates on current working tree.

## Instructions

### 1. Gather Change Information

Run these commands to understand the full picture:

```bash
git status                    # All modified/untracked files
git diff --stat               # Summary of changes
git diff                      # Full diff of unstaged changes
git diff --cached             # Full diff of staged changes
git log --oneline -5          # Recent commit style
```

### 2. Analyze Each Changed File

For each modified/added file, determine:

- **Domain**: What area of the codebase (UI, backend, docs, tests, config, etc.)
- **Purpose**: What is this change doing (new feature, bug fix, refactor, docs, chore)
- **Related files**: Which other changes are logically connected

### 3. Group Changes Logically

Create groups based on:

| Grouping Principle | Example                                               |
| ------------------ | ----------------------------------------------------- |
| Same feature       | `user-auth.ts` + `user-auth.test.ts` + `docs/auth.md` |
| Same domain        | All spec files together, all UI components together   |
| Same purpose       | All lint fixes, all dependency updates                |
| Minimal coupling   | Changes that can be reverted independently            |

**Rules:**

- Never combine unrelated changes
- Keep groups atomic and reversible
- One group per logical unit of work
- Prefer smaller, focused groups over large ones

### 4. Determine Change Type Per Group

For each group, classify as:

| Type         | Criteria                                                   | Version Impact |
| ------------ | ---------------------------------------------------------- | -------------- |
| **BREAKING** | Removes/changes public API, breaks backwards compatibility | Major          |
| **feat**     | New functionality, new capability                          | Minor          |
| **fix**      | Bug fix, error correction                                  | Patch          |
| **refactor** | Code restructuring, no behavior change                     | Patch          |
| **docs**     | Documentation only                                         | Patch          |
| **test**     | Test additions/changes only                                | Patch          |
| **chore**    | Build, config, dependencies                                | Patch          |
| **style**    | Formatting, whitespace                                     | Patch          |
| **perf**     | Performance improvement                                    | Patch          |

**Determining overall bump type:**

- If ANY group is BREAKING -> overall bump is **major**
- Else if ANY group is feat -> overall bump is **minor**
- Else -> overall bump is **patch**

### 5. Generate Commit Plan

For each group, produce:

```yaml
group: 1
files:
  - path/to/file1.ts
  - path/to/file2.ts
type: feat
summary: "Add user authentication flow"
details:
  - Implement login form component
  - Add auth context and hooks
  - Create protected route wrapper
```

### 6. Return Analysis

Output a structured commit plan:

```text
=== CHANGE ANALYSIS ===

Overall version bump: minor (feat detected)

--- Group 1 of 3 ---
Type: feat
Summary: Add user authentication flow
Files:
  - src/components/LoginForm.tsx
  - src/contexts/AuthContext.tsx
  - src/hooks/useAuth.ts
Details:
  - Implement login form component
  - Add auth context and hooks
  - Create protected route wrapper

--- Group 2 of 3 ---
Type: docs
Summary: Update API documentation
Files:
  - docs/api.md
  - docs/authentication.md
Details:
  - Document new auth endpoints
  - Add usage examples

--- Group 3 of 3 ---
Type: fix
Summary: Fix null pointer in user service
Files:
  - src/services/userService.ts
  - src/services/userService.test.ts
Details:
  - Add null check before accessing user.email
  - Add regression test

=== END ANALYSIS ===
```

## Important Notes

- This skill ONLY analyzes - it does NOT commit
- The commit skill uses this output to execute commits
- If working tree is clean, report "No changes to analyze"
- Untracked files should be considered (may need `git add` first)
- Large binary files or generated files should typically be separate groups
