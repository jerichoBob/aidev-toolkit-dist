---
name: sdd-spec-owner
description: "Set or unset the owner of a spec"
argument-hint: "<version> [set <email> | unset]"
allowed-tools: Read, Edit, Bash(~/.claude/aidev-toolkit/modules/sdd/scripts/*:*)
user-invocable: false
---

# Spec Owner Management

Manage spec ownership by setting or unsetting the owner email in the Quick Status table.

## Usage

```text
/sdd-spec-owner <version> set <email>    Set owner of spec
/sdd-spec-owner <version> unset          Clear owner of spec
```

## Instructions

### Step 1: Parse Arguments

Parse `$ARGUMENTS` to extract:

- **version**: The spec version (e.g., `v15`, `15`, or `v15.2`)
- **action**: Either `set` or `unset`
- **email**: The email address (required if action is `set`)

Normalize version: if user provides `15`, convert to `v15`. Support decimal versions like `v15.2`.

### Step 2: Validate Spec Exists

Run this command to check if the spec exists:

```bash
~/.claude/aidev-toolkit/modules/sdd/scripts/specs-parse.sh status | grep "^${version}"
```

If no match found, report error: "Spec {version} not found. Run `/sdd-specs` to see available specs."

### Step 3: Update Owner in README

Read `specs/README.md` and locate the Quick Status table.

Find the row for the specified version.

**For `set` action:**

- Replace the Owner column value with `$EMAIL`
- If the spec was owned by someone else, report: "⚠️  Spec was previously owned by {previous_email}"

**For `unset` action:**

- Replace the Owner column value with `—` (em dash)

Write the updated README.

### Step 4: Report Result

**For `set`:**

```text
✅ Owner updated
Spec: v{N}: {Name}
Owner: {email}
```

**For `unset`:**

```text
✅ Owner cleared
Spec: v{N}: {Name}
Owner: —
```

## Examples

```text
/sdd-spec-owner v15 set bob@example.com
/sdd-spec-owner 15 set alice@company.com
/sdd-spec-owner v15.2 unset
```

## Error Handling

- If version is missing: "Error: Spec version required. Usage: /sdd-spec-owner <version> [set <email> | unset]"
- If action is missing: "Error: Action required. Use 'set <email>' or 'unset'."
- If action is `set` but email is missing: "Error: Email required for 'set' action."
- If spec not found: "Error: Spec {version} not found."
