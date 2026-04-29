---
name: sdd-spec-tagging
tier: extended
description: "Reference document for the spec-tagging commit convention — traceable spec-to-code mapping via [vN:pN:sN] tags"
disable-model-invocation: false
---

# Spec Tagging Convention

A commit-tagging convention for traceable spec-to-code mapping.

## Status: PROPOSED

This documents a future convention for consideration. Currently using code search via `/sdd-specs --verify`.

## The Convention

Include spec reference in commit messages using the format `[vN:pN:sN]`:

```text
feat: add interaction logging [v7:p1:s5]

Implements log_interaction() method in MongoLogger.
```

### Format

`[v{VERSION}:p{PHASE}:s{STEP}]`

| Part    | Description                       | Example |
| ------- | --------------------------------- | ------- |
| VERSION | Spec version number               | v7      |
| PHASE   | Phase number within spec          | p1      |
| STEP    | Step/checkbox number within phase | s5      |

### Examples

```text
feat: add Recent Interactions table [v7:p4:s1]
fix: handle empty session state [v7:p2:s4]
refactor: extract timezone helpers [v7:p1:s2]
```

## Benefits

- **Fast verification**: `git log --grep="v7:p1"` finds all Phase 1 commits
- **Definitive traceability**: Know exactly which commit implements which spec item
- **Audit trail**: Easy to review what was done for each requirement
- **Works with `/sdd-specs --verify`**: Can look up git history instead of searching code

## When to Adopt

Consider adopting this convention when:

- Team grows beyond 1-2 people
- Specs become more granular with many small items
- Audit trail becomes important (compliance, reviews)
- You want faster `/sdd-specs --verify` execution

## Migration Path

If adopting this convention mid-project:

1. **v1-v5 (complete)**: Leave as-is, no need to retrofit
2. **v6+ (in progress/draft)**: Start using tags for new commits
3. **`/sdd-specs --verify`**: Falls back to code search for items without commit tags

## Integration with /sdd-specs --verify

When this convention is adopted, `/sdd-specs --verify` could be enhanced to:

1. First check `git log --grep="[vN:pN:sN]"` for tagged commits
2. Fall back to code search for untagged items
3. Report which items have commit tags vs which were found via search
