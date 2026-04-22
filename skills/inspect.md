---
name: inspect
description: Analyze any codebase - identity, architecture, tech stack.
argument-hint: [--brief|--deep]
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(ls:*)
model: inherit
---

# Inspect Codebase

Analyze and describe the current codebase in a standardized format.

## When to Use

- User asks "what is this project?", "explain this codebase", or "how does this work?"
- Onboarding to a new or unfamiliar codebase
- Generating documentation about project structure
- Understanding tech stack, conventions, and development workflow

## Arguments

- `--brief`: Essential info only (name, stack, how to run)
- `--deep`: Full analysis including code patterns and domain model
- (no argument): Standard report with all sections

## Instructions

Analyze the current codebase and produce a structured overview. The goal is to give a developer everything they need to understand and contribute to this project.

### Step 1: Discover Project Type

Identify the project by checking for:

- `package.json` → Node.js/JavaScript/TypeScript
- `pyproject.toml` or `requirements.txt` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` or `build.gradle` → Java
- `*.csproj` or `*.sln` → .NET

### Step 2: Gather Information

Read key files to extract information:

| File                | Extract                                    |
| ------------------- | ------------------------------------------ |
| Package manifest    | Name, version, dependencies, scripts       |
| `README.md`         | Description, setup instructions            |
| `CLAUDE.md`         | AI guidance, architecture notes            |
| Directory structure | Architecture pattern, organization         |
| Config files        | `.env.example`, `docker-compose.yml`, etc. |
| Source entry points | Main files, API routes                     |
| Test files          | Testing patterns, coverage                 |

### Step 3: Produce Output

Based on the detail level requested:

#### Brief (`--brief`)

Output a compact reference:

```text
<project-name> - <one-line description>
Stack: <language> / <runtime> / <framework>
---
<install-cmd>     Install dependencies
<run-cmd>         Run locally
<test-cmd>        Run tests
```

#### Standard (default)

Output a full structured report in markdown:

```markdown
# Codebase Overview: <project-name>

## Identity

- **Description**: <description>
- **Repository**: <repo-url if detectable>
- **Version**: <version>
- **Stack**: <language> / <runtime> / <framework>

## Architecture Overview

<Describe the architecture pattern: monolith, microservice, serverless, etc.>

Key directories:

- `<dir>/` - <purpose>
- `<dir>/` - <purpose>

Entry point: `<file>` -> <what it does>

## Tech Stack

- **Runtime**: <runtime and version>
- **Framework**: <framework>
- **Database**: <database if any>
- **External Services**: <list integrations>

## Development Workflow

    <install-command>    # Install dependencies
    <run-command>        # Run locally
    <test-command>       # Run tests
    <build-command>      # Build for production

Environment: <reference .env.example or list key vars>

## Code Conventions

- <Observed pattern 1>
- <Observed pattern 2>
- <Observed pattern 3>

## Domain Context

<What problem does this solve?>

Key entities:

- **<Entity>**: <description>
- **<Entity>**: <description>
```

#### Deep (`--deep`)

Include everything from standard, plus:

```markdown
## Code Patterns

### Error Handling

<Describe observed error handling patterns>

### Logging

<Describe logging approach>

### Testing

<Describe testing patterns and coverage>

## Dependency Analysis

Key dependencies and their purposes:

- `<package>` - <why it's used>
- `<package>` - <why it's used>

## Domain Model

<Describe entities, relationships, and business rules>

## Architecture Decisions

Based on the code, these design decisions were made:

- <Decision 1 and apparent rationale>
- <Decision 2 and apparent rationale>

## Technical Debt

Observed issues or inconsistencies:

- <Issue 1>
- <Issue 2>
```

## Important Notes

- Be factual and specific. Reference actual file paths and code.
- Don't make up information. If something isn't clear, say so.
- For --brief, keep it under 10 lines total.
- For --deep, be thorough but stay focused on what matters for understanding the codebase.
