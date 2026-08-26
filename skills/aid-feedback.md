---
name: aid-feedback
tier: core
description: Submit feedback, suggestions, or feature requests for aidev toolkit.
argument-hint: "[type area description | --ingest]"
allowed-tools: Read, Bash(gh issue create:*), Bash(gh issue list:*), Bash(gh issue edit:*), Bash(gh label create:*), Bash(gh auth status:*), Bash(gh api user:*), Bash(find:*), Bash(touch:*), AskUserQuestion
model: sonnet
---

# aidev toolkit Feedback

<!-- NO LOCAL FILES — GitHub Issues only, no Slack, no secrets required -->

Submit feedback, suggestions, bug reports, or feature requests for aidev toolkit. Feedback is posted as GitHub Issues on `jerichoBob/aidev-toolkit-dist` (the public distribution repo) using your existing `gh` CLI auth — no webhook, no tokens, no setup.

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

### Step 0b: Ensure Required Labels Exist (cached — skip if recently verified)

Labels essentially never change once created, so avoid re-issuing 4 `gh label create` calls on every invocation. Check for a local marker per repo:

```bash
MARKER_TOOLKIT="$HOME/.claude/aidev-toolkit/.labels-verified-jerichoBob-aidev-toolkit"
MARKER_DIST="$HOME/.claude/aidev-toolkit/.labels-verified-jerichoBob-aidev-toolkit-dist"
```

For each repo, check whether its marker file exists AND was modified within the last 30 days:

```bash
find "$MARKER_TOOLKIT" -mtime -30 2>/dev/null
find "$MARKER_DIST" -mtime -30 2>/dev/null
```

- **If a marker is found (fresh, ≤30 days old)**: skip the `gh label create` calls for that repo — labels are assumed to exist.
- **If a marker is missing, stale (>30 days), or a later `gh issue create`/`gh issue edit` call in this run fails with a label-related error**: run the create calls for that repo (safe to run even if labels already exist) and then write/refresh its marker:

```bash
# aidev-toolkit (private): labels retained for ingestion-side labeling of
# historical/legacy issues only — this repo is no longer a filing target.
gh label create feedback --repo jerichoBob/aidev-toolkit --description "User feedback submitted via /aid-feedback" --color "0075ca" --force 2>/dev/null || true
gh label create processed --repo jerichoBob/aidev-toolkit --description "Feedback ingested and specced" --color "e4e669" --force 2>/dev/null || true
touch "$MARKER_TOOLKIT"
# aidev-toolkit-dist (public): sole filing target for all new feedback issues.
gh label create feedback --repo jerichoBob/aidev-toolkit-dist --description "User feedback submitted via /aid-feedback" --color "0075ca" --force 2>/dev/null || true
gh label create processed --repo jerichoBob/aidev-toolkit-dist --description "Feedback ingested and specced" --color "e4e669" --force 2>/dev/null || true
touch "$MARKER_DIST"
```

These labels are required for ingestion filtering and processing. The `--force` flag updates color/description if the label already exists. If a later step in this run hits a label-related failure despite a fresh marker, treat the marker as stale: re-run the create calls for the affected repo and refresh its marker before retrying.

---

### Ingestion Mode (runs when BOTH are true)

Check these conditions:

1. `$ARGUMENTS` is empty OR `$ARGUMENTS` is `--ingest`
2. The authenticated GitHub user is the maintainer — run `gh api user --jq .login` and confirm it returns `jerichoBob`. (Optionally verify `modules/sdd/` exists in the cwd as a secondary sanity check.)

**If both conditions are met, run ingestion mode:**

#### Step 1: Read Open Feedback Issues

Query both repos and merge the results:

```bash
gh issue list --repo jerichoBob/aidev-toolkit --label feedback --state open --json number,title,body,author,createdAt,labels
gh issue list --repo jerichoBob/aidev-toolkit-dist --state open --json number,title,body,author,createdAt,labels
```

The source repo (`aidev-toolkit`) is filtered by the `feedback` label since all issues there are intentional toolkit feedback. The dist repo (`aidev-toolkit-dist`) is queried unfiltered — users filing issues against the dist repo may not know to add the label, and we should never blind ourselves to those reports.

If either command fails, show the error and stop.

Merge the two JSON arrays into a single combined list. Tag each issue object with a synthetic `repo` field indicating its source:

- Issues from `jerichoBob/aidev-toolkit` → `"repo": "jerichoBob/aidev-toolkit"`
- Issues from `jerichoBob/aidev-toolkit-dist` → `"repo": "jerichoBob/aidev-toolkit-dist"`

If the combined merged list is empty (`[]`), print:

```text
No open feedback issues — nothing to ingest.
```

Then stop.

**Filter out already-processed issues:** from the combined array, remove any issue where the `labels` array contains an entry with `name == "processed"`. Work only with the remaining unprocessed issues.

If the filtered list is empty, print:

```text
No new feedback issues — all open issues are already processed.
```

Then stop.

#### Step 2: Parse and Classify Issues

For each unprocessed issue object `{ number, title, body, author, createdAt, labels }`, determine:

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

For each confirmed item, handle by type:

**If type is `bug`:** Follow the Bug Triage Protocol before creating a spec:

1. **Reproduce first** — read `.claude/commands/bug-repro.md` and follow it. Do not write any fix or spec until you have a confirmed repro.
2. State the repro result clearly:
   - ✅ **Reproduced**: describe the exact command that fails and the exact error
   - ❌ **Cannot reproduce**: say so, note what was tried, ask for more info — do NOT proceed to spec
   - ⊘ **Blocked**: note what's missing (hardware, credentials, external service)
3. Only after a confirmed ✅ repro: write a `.claude/scripts/repro-{area}.sh` that demonstrates the failure, then invoke `/sdd-spec` with the root cause included in the description:

```text
/sdd-spec [BUG] /sdd-code — fails when specs dir is missing; root cause: X; repro: .claude/scripts/repro-sdd-code.sh
```

**If type is `feature`, `enhancement`, or `doc`:** Invoke `/sdd-spec` directly:

```text
/sdd-spec [FEATURE] /commit — add --dry-run flag
```

Wait for each spec to be created before proceeding to the next.

**After each spec is created**, patch it with the source issue number and repo:

1. Add `github_issue: {number}` to the spec's YAML frontmatter (after `depends_on`)
2. Add `github_issue_repo: {repo}` to the spec's YAML frontmatter (immediately after `github_issue`), where `{repo}` is the `repo` field from the issue object (e.g., `jerichoBob/aidev-toolkit-dist`)
3. Add a final task to the spec's README section:

   ```text
   - [ ] Close GitHub issue #{number} (gh issue close {number} --repo {repo})
   ```

   Use the correct `{repo}` from the issue object. This task must be the last item in the last phase of the README section — it is the archival handoff step.

#### Step 8: Label Processed Issues

For each issue that was confirmed (specced or intentionally skipped), apply labels using the `repo` field from the issue object:

```bash
gh issue edit {number} --repo {repo} --add-label processed --add-label feedback
```

Adding both labels ensures every processed issue is also tagged `feedback` — catching dist repo issues that were filed without it. The `--force` label creation in Step 0b guarantees both labels exist before this runs.

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
  --repo jerichoBob/aidev-toolkit-dist \
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
✓ Feedback submitted to jerichoBob/aidev-toolkit-dist

Type:    {type}
Area:    {area}
Message: {description}
Issue:   {issue URL}
```
