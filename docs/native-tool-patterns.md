# Native Tool Patterns

Use Claude Code's built-in tools instead of shell commands whenever possible. Native tools require no Bash permission prompts and are faster.

## Substitution Table

| Instead of (Bash) | Use (Native Tool) | Notes |
|-------------------|-------------------|-------|
| `cat file` | `Read` | No permission prompt |
| `head -n N file` | `Read` with `limit` | |
| `tail -n N file` | `Read` with `offset` + `limit` | |
| `grep pattern file` | `Grep` | Supports regex, context lines |
| `find . -name "*.md"` | `Glob` | Pattern matching |
| `ls dir/` | `Glob` with `*` | |
| `sed -i 's/old/new/' file` | `Edit` | Exact string replacement |
| `awk '{print $1}' file` | `Read` → parse in context | |
| `echo "content" > file` | `Write` | Full file create/overwrite |

## Rule

**Reserve `Bash` for:**

- `git` commands (`git status`, `git diff`, `git commit`, etc.)
- `gh` CLI commands
- External CLIs with no native equivalent (`cloc`, `shasum`, `curl`, etc.)
- Multi-step shell pipelines where no tool combination suffices

**Never use `Bash` for:**

- Reading file contents → use `Read`
- Searching file contents → use `Grep`
- Finding files by name → use `Glob`
- Editing/replacing text in files → use `Edit`
- Writing new files → use `Write`

## allowed-tools Examples

```yaml
# Good — git-only bash, file ops use native tools
allowed-tools: Read, Edit, Grep, Glob, Bash(git:*)

# Good — also needs gh CLI
allowed-tools: Read, Edit, Grep, Glob, Bash(git:*), Bash(gh:*)

# Bad — unnecessary bash for file ops
allowed-tools: Bash(cat:*), Bash(grep:*), Bash(sed:*), Bash(find:*)
```

## Why This Matters

Each `Bash` call with a new command requires a separate user permission in non-auto-approve mode. A skill that uses `cat`, `grep`, `sed`, and `find` for file operations can generate 4–8 prompts per invocation. Native tools are silently approved when listed in `allowed-tools`.
