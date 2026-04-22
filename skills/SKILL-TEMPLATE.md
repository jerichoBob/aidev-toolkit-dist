# Claude Code Skill Template (SOTA)

Reference template for creating new aidev toolkit skills.

## Official Frontmatter Fields

| Field                      | Type    | Description                                             |
| -------------------------- | ------- | ------------------------------------------------------- |
| `name`                     | string  | Skill identifier (lowercase, hyphens, max 64 chars)     |
| `description`              | string  | **Short** - Single line for menu display (~60-80 chars) |
| `argument-hint`            | string  | Hint for expected arguments shown in UI                 |
| `allowed-tools`            | string  | Comma-separated tools without permission prompts        |
| `model`                    | string  | `sonnet`, `opus`, `haiku`, or `inherit`                 |
| `context`                  | string  | `fork` for isolated subagent context                    |
| `agent`                    | string  | Subagent type: `Explore`, `Plan`, `general-purpose`     |
| `disable-model-invocation` | boolean | Prevent Claude auto-triggering                          |
| `user-invocable`           | boolean | Hide from `/` menu if `false`                           |
| `hooks`                    | object  | Lifecycle hooks (PreToolUse, PostToolUse, Stop)         |

## Tool Names for `allowed-tools`

**Core Tools:**

- `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`
- `WebFetch`, `WebSearch`
- `Task` (subagent delegation)
- `Notebook` (Jupyter)
- `AskUserQuestion`

**Scoped Bash Syntax:**

```yaml
allowed-tools: Bash(git:*), Bash(npm:*), Bash(cloc:*)
```

**IMPORTANT: Include ALL commands your skill uses.**

If your skill instructions tell Claude to run commands, those commands MUST be in `allowed-tools` or users will get permission prompts.

Common mistakes:

| Instruction             | Missing Permission                             |
| ----------------------- | ---------------------------------------------- |
| `find ... \| xargs ...` | Need both `Bash(find:*)` AND `Bash(xargs:*)`   |
| `awk ...`               | Need `Bash(awk:*)`                             |
| `grep ...`              | Use `Grep` tool instead, or add `Bash(grep:*)` |
| `cat file`              | Use `Read` tool instead                        |

When adding features that use new commands, update `allowed-tools` in the same commit.

## Tool Selection (Native-First Pattern)

**Always prefer native tools over Bash for file operations.** Native tools require no permission prompts and are faster.

| Operation                   | Use This | Not This       |
| --------------------------- | -------- | -------------- |
| Read a file                 | `Read`   | `Bash(cat:*)`  |
| Search file contents        | `Grep`   | `Bash(grep:*)` |
| Find files by name          | `Glob`   | `Bash(find:*)` |
| Edit/replace text in a file | `Edit`   | `Bash(sed:*)`  |
| Write a new file            | `Write`  | `Bash(echo:*)` |

**Reserve `Bash` for:** `git`, `gh`, and external CLIs with no native equivalent.

See [`docs/native-tool-patterns.md`](../docs/native-tool-patterns.md) for the full substitution table and rationale.

## Template

```yaml
---
name: my-skill
description: Short description for menu display (~60-80 chars).
argument-hint: [arg1] [arg2]
allowed-tools: Read, Grep, Glob, Bash(git:*)
model: inherit
---

# Skill Title

Brief overview of what this skill does.

## When to Use

Detailed context for Claude's auto-invocation (put verbose description here, not in YAML):

- User asks "trigger phrase 1" or "trigger phrase 2"
- Specific scenario when this skill applies
- Example use cases

## Arguments

- **arg1**: Description of first argument
- **arg2**: Description of second argument
- **--flag**: Description of flag

## Instructions

### Step 1: First Step

Detailed instructions for step 1.

### Step 2: Second Step

Detailed instructions for step 2.

## Output

Expected output format or examples.

## Important Notes

- Key consideration 1
- Key consideration 2
```

## Output Verbosity

**Default to minimal, task-level output.** Users see tool calls in the UI already—don't narrate what you're about to do.

**Avoid:**

- "Let me check the current version..."
- "Now I'll update the changelog..."
- "I'm going to run git status to verify..."

**Prefer:**

```text
Pulling... OK
Analyzing...

=== CHANGES ===
Type: docs (patch)
Summary: Update README

Committing... OK
Done! Version 1.2.4
```

**Add `--verbose` flag** for skills that do multi-step work. When verbose:

- Include narration and reasoning
- Show intermediate results and file contents
- Display full command output

```yaml
## Arguments

- **--verbose**: Show detailed output including narration and intermediate results

## Output Style

**Default: Minimal task-level output.** No narration, just progress indicators.

**With --verbose:** Include narration, intermediate results, and details.
```

## Supporting Skills (Hidden from Menu)

For skills that are called by other skills (not directly by users):

```yaml
---
name: my-helper-skill
description: Supporting skill for /parent-skill. Does X and Y.
allowed-tools: Read, Glob, Grep
user-invocable: false
model: inherit
---
```

Note: Supporting skills don't need "## When to Use" sections since they have `user-invocable: false`.

## Hooks Example

```yaml
---
name: my-skill
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
          timeout: 30
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: 'prettier --write "$(jq -r .tool_input.file_path)"'
  Stop:
    - hooks:
        - type: command
          command: "./scripts/cleanup.sh"
---
```

**Hook Exit Codes:**

- **0**: Success (pass)
- **2**: Block (prevents tool call, shows error to Claude)
- **Other**: Non-blocking warning

## Dynamic Context

Inject live data with backticks in skill body:

```markdown
Current branch: `git branch --show-current`
PR diff: `gh pr diff`
```

## Variables

Available in skill body:

- `$ARGUMENTS` - All arguments as string
- `$0`, `$1`, `$2` - Positional arguments
- `${CLAUDE_SESSION_ID}` - Session ID

## File Organization (Multi-file Skills)

For complex skills, use a directory structure:

```text
skill-name/
├── SKILL.md              # Main file (keep under 500 lines)
├── scripts/              # Executable helpers
│   └── validate.sh
└── references/           # Supporting docs (loaded on demand)
    ├── api.md
    └── examples.md
```

## Sources

- <https://docs.anthropic.com/en/docs/claude-code/skills>
- <https://docs.anthropic.com/en/docs/claude-code/hooks>
- <https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md>
