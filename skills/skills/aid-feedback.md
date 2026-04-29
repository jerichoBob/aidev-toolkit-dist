---
name: aid-feedback
tier: core
description: Submit feedback, suggestions, or feature requests for aidev toolkit.
argument-hint: [type area description | --ingest]
allowed-tools: Read, Bash(gh issue create:*), Bash(gh issue list:*), Bash(gh issue edit:*), Bash(gh label create:*), Bash(gh auth status:*), Bash(gh api user:*), AskUserQuestion
model: sonnet
---

# aidev toolkit Feedback

<!-- NO LOCAL FILES — GitHub Issues only, no Slack, no secrets required -->

Submit feedback, suggestions, bug reports, or feature requests for aidev toolkit. Feedback is posted as GitHub Issues on `jerichoBob/aidev-toolkit` using your existing `gh` CLI auth — no webhook, no tokens, no setup.

## When to Use

- User wants to suggest a new feature for aidev toolkit
- User found a bug or issue to report
- User has feedback on existing skills

## Arguments

- **(empty)**: Interactive feedback submission (or ingestion mode if inside aidev-toolkit repo)
- **type area description**: Direct submission (e.g., `bug /screenshots crashes on spaces`)
- **--ingest**: Force ingestion mode (reads open feedback issues, creates specs)

## Instructions

### Step 0: Check gh Auth

Before anything else:

```bash
gh auth status
```

If this fails (exit code non-zero):

```text
Error: GitHub CLI is not authenticated.

Run: gh auth login
Then retry /aid-feedback.
```

Stop here.

### Step 0b: Ensure Required Labels Exist

Ensure the `feedback` and `processed` labels exist on the repo (safe to run even if they already exist):

```bash
gh label create feedback --repo jerichoBob/aidev-toolkit --description "User feedback submitted via /aid-feedback" --color "0075ca" --force 2>/dev/null || true
gh label create processed --repo jerichoBob/aidev-toolkit --description "Feedback ingested and specced" --color "e4e669" --force 2>/dev/null || true
```

These labels are required for ingestion filtering and processing. The `--force` flag updates color/description if the label already exists.

---

### Ingestion Mode (runs when BOTH are true)

Check these conditions:

1. `$ARGUMENTS` is empty OR `$ARGUMENTS` is `--ingest`
2. The authenticated GitHub user is the maintainer — run `gh api user --jq .login` and confirm it returns `jerichoBob`. (Optionally verify `modules/sdd/` exists in the cwd as a secondary sanity check.)

**If both conditions are met, run ingestion mode:**

#### Step 1: Read Open Feedback Issues

```bash
gh issue list --repo jerichoBob/aidev-toolkit --label feedback --state open --json number,title,body,author,createdAt
```

Capture the JSON output. If the command exits with an error, show the error and stop.

If the JSON array is empty (`[]`), print:

```text
No open feedback issues — nothing to ingest.
```

Then stop.

#### Step 2: Parse and Classify Issues

For each issue object `{ number, title, body, author, createdAt }`, determine:

- **type**: one of `bug` / `feature` / `enhancement` / `doc` — infer from title prefix `[TYPE]` if present, otherwise from content
- **area**: closest match from the title or body — skill name (e.g. `/screenshots`) or `General/Toolkit`
- **description**: concise one-sentence summary of the ask

#### Step 3: Deduplication Pass

Collapse near-identical items where `type` + `area` + core ask are essentially the same. Track how many originals were merged into each deduplicated item.

#### Step 4: Priority Sort

Order: P0 bugs → P1 features → P2 enhancements → P3 docs

#### Step 5: Present to User

Display a numbered list:

```text
Open Feedback Issues — N items (M duplicates collapsed)
========================================================

1. [BUG] Specific Skill — /sdd-code fails when specs dir is missing (2 reports)
2. [FEATURE] General/Toolkit — Add --dry-run flag to /commit
3. [ENHANCEMENT] Specific Skill — /inspect should detect monorepos
...
```

#### Step 6: Confirm Which Items to Spec

Use AskUserQuestion to confirm which items to create specs for. The user can deselect any items. Default is all items selected.

#### Step 7: Create Specs

For each confirmed item, invoke `/sdd-spec` with a prompt that includes type, area, and description. For example:

```text
/sdd-spec [BUG] /sdd-code — fails when specs dir is missing; add guard and helpful error message
```

Wait for each spec to be created before proceeding to the next.

#### Step 8: Label Processed Issues

For each issue that was confirmed (specced or intentionally skipped), add the `processed` label:

```bash
gh issue edit {number} --repo jerichoBob/aidev-toolkit --add-label processed
```

#### Step 9: Print Summary

```text
Ingestion Complete
==================
Specs created:    N
Items combined:   M (from K original issues)
Items skipped:    P (deselected by user)
Issues labeled:   Q (marked as processed)
```

---

### Otherwise: Submit Feedback

#### Step 1: Parse Arguments

From `$ARGUMENTS`, attempt to extract:

- **type**: Look for `bug`, `feature`, `enhancement`, or `doc` as the first word. Map to full label: bug → "Bug Report", feature → "Feature Request", enhancement → "Improvement", doc → "Documentation"
- **area**: Look for a `/skill-name` pattern or a descriptive phrase after the type word
- **description**: Remaining text after type and area

If ALL of type, area, and description can be inferred from `$ARGUMENTS`: proceed to Step 2.

If ANY are missing or ambiguous, ask ONCE using AskUserQuestion:

```text
What feedback do you have? Please include:
- Type: bug / feature / enhancement / doc
- Area: skill name (e.g. /screenshots) or "General/Toolkit"
- Description: what happened or what you'd like
```

#### Step 2: Map Type to Label

| Input       | GitHub label    |
| ----------- | --------------- |
| bug         | `bug`           |
| feature     | `enhancement`   |
| enhancement | `enhancement`   |
| doc         | `documentation` |

TYPE badge for title/body: bug → BUG, feature → FEATURE, enhancement → ENHANCEMENT, doc → DOC

#### Step 3: Get Submitter

```bash
gh api user --jq .login
```

Use the returned GitHub username as the submitter.

#### Step 4: Create GitHub Issue

```bash
gh issue create \
  --repo jerichoBob/aidev-toolkit \
  --title "[TYPE] area — description" \
  --body "$(cat <<'EOF'
## aidev toolkit Feedback

**Type:** {full type label}
**Area:** {area}
**Submitted by:** @{github_username}
**Date:** {YYYY-MM-DD}

## Description

{description}

---
*Submitted via /aid-feedback*
EOF
)" \
  --label "feedback" \
  --label "{type-github-label}"
```

Capture the issue URL from the output.

#### Step 5: Confirm

```text
✓ Feedback submitted to jerichoBob/aidev-toolkit

Type:    {type}
Area:    {area}
Message: {description}
Issue:   {issue URL}
```
