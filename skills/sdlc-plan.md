---
name: sdlc-plan
description: Analyze business documents (RFQ, RFP, PRD, SOW) for planning.
argument-hint: @document.pdf [--output <dir>]
allowed-tools: Read, Glob, Grep, Bash(ls:*), Bash(cp:*), Bash(mkdir:*)
model: inherit
---

# SDLC Plan

Analyze business documents and produce structured analysis for implementation planning.

**Primary use case:** "We have a document describing what to build—turn it into a plan we can execute."

## When to Use

- User provides a business document (RFQ, RFP, PRD, SOW) to analyze
- Starting a new project and need to extract requirements, architecture, and phases
- Converting business documents into actionable implementation plans
- Preparing documents for `/deal-desk` (deal qualification) or `/spec` (implementation)
- User asks "what does this document say?", "break down this PRD", or "plan this project"

## Arguments

- **@document**: `/sdlc-plan @rfq.pdf` - Analyze a document (PDF, DOCX)
- **Multiple docs**: `/sdlc-plan @rfq.pdf @requirements.xlsx` - Analyze with supplementary files
- **--output `<dir>`**: Custom output directory (default: `./analysis/`)

## Supported Document Types

| Type               | Description                    | Key Extraction Focus                        |
| ------------------ | ------------------------------ | ------------------------------------------- |
| **RFQ/RFP**        | Request for Quotation/Proposal | Phases, evaluation criteria, cost buckets   |
| **PRD**            | Product Requirements Document  | Features, user stories, acceptance criteria |
| **SOW**            | Statement of Work              | Deliverables, milestones, acceptance        |
| **Technical Spec** | Architecture/design document   | Components, integrations, constraints       |

The skill adapts extraction based on document type but produces **consistent output structure**.

## Output Structure

**CRITICAL: Generate EXACTLY these 6 documents. No more, no fewer.**

```text
analysis/
├── README.md                    # Index with links and one-sentence summary
├── 01-executive-summary.md      # Business context, goals, success criteria
├── 02-requirements-matrix.md    # All requirements with IDs, priorities, acceptance criteria
├── 03-technical-architecture.md # System design, components, integrations
├── 04-data-model.md             # Entities, relationships, storage patterns
├── 05-complexity-estimate.md    # Risk factors, skill requirements, open questions
├── 06-implementation-phases.md  # Sprint/phase breakdown with task checklists
└── source-docs/                 # Copies of input documents
    └── <original-filename>.*
```

If additional analysis is needed beyond these 6 documents, create appendices numbered `A1-`, `A2-`, etc. (e.g., `A1-compliance-requirements.md`). Appendices should be rare exceptions, not the norm.

## Instructions

### Step 1: Read and Classify Input

Read all provided documents thoroughly. Classify the primary document type:

| Signal                                                                  | Likely Type    |
| ----------------------------------------------------------------------- | -------------- |
| "Request for Quotation/Proposal", evaluation criteria, bid instructions | RFQ/RFP        |
| User stories, personas, feature lists, wireframes                       | PRD            |
| Deliverables, payment schedule, acceptance procedures                   | SOW            |
| System diagrams, API specs, data schemas                                | Technical Spec |

Note: A single document may contain elements of multiple types. Extract all relevant information regardless of classification.

### Step 2: Extract Core Information

Build a mental model of:

1. **The Goal** - What is being built and why? (Must be expressible in one sentence)
2. **The Users** - Who will use this? What are their primary workflows?
3. **The Requirements** - What must the system do? What are the acceptance criteria?
4. **The Constraints** - Timeline, budget, technology, compliance, integrations
5. **The Phases** - How is delivery structured? What's MVP vs. full rollout?

### Step 3: Produce High-Level Summary in Chat

Before generating files, present a summary for validation:

```markdown
## Analysis Summary

**One-sentence goal:** <clear, specific statement of what's being built and why>

**Document type:** <RFQ/RFP | PRD | SOW | Technical Spec>

**Core data entities:**

- <Entity 1>
- <Entity 2>
- <Entity 3>

**Key user personas:**
| Persona | Primary Goal |
|---------|--------------|
| <Role 1> | <What they need to accomplish> |
| <Role 2> | <What they need to accomplish> |

**Requirements breakdown:**
| Priority | Count | Examples |
|----------|-------|----------|
| P0 (Essential) | X | <brief examples> |
| P1 (Must-have) | X | <brief examples> |
| P2 (Important) | X | <brief examples> |
| P3 (Nice-to-have) | X | <brief examples> |

**Phase structure:**
| Phase | Focus | Key Deliverables |
|-------|-------|------------------|
| MVP/Pilot | <focus> | <deliverables> |
| Full Rollout | <focus> | <deliverables> |
| Future | <focus> | <deliverables> |

**Key risks identified:** <2-3 bullet points>

**Output directory:** <path> (confirm or specify alternative)
```

Ask clarifying questions if:

- The goal is unclear or contradictory
- Requirements have significant gaps
- Phase boundaries are ambiguous
- Technology constraints are unspecified but relevant

### Step 4: Generate Analysis Documents

Create the output directory and copy source documents:

```bash
mkdir -p <output-dir>/source-docs
cp <input-files> <output-dir>/source-docs/
```

Generate each document following the specifications below.

---

## Document Specifications

### README.md

```markdown
# Analysis: <Project Name>

**Analyzed:** <YYYY-MM-DD>
**Source:** <document filename(s)>
**Type:** <RFQ/RFP | PRD | SOW | Technical Spec>

## One-Sentence Goal

<Clear, specific statement of what's being built and why>

## Documents

| #   | Document                                               | Description                           |
| --- | ------------------------------------------------------ | ------------------------------------- |
| 01  | [Executive Summary](01-executive-summary.md)           | Business context and success criteria |
| 02  | [Requirements Matrix](02-requirements-matrix.md)       | Full requirements with priorities     |
| 03  | [Technical Architecture](03-technical-architecture.md) | System design and integrations        |
| 04  | [Data Model](04-data-model.md)                         | Entities and relationships            |
| 05  | [Complexity Estimate](05-complexity-estimate.md)       | Risk factors and open questions       |
| 06  | [Implementation Phases](06-implementation-phases.md)   | Sprint breakdown and tasks            |

## Next Steps

- [ ] Run `/deal-desk ./analysis/` for deal qualification
- [ ] Review with stakeholders for validation
- [ ] Create specs for P0 requirements: `/spec create`
```

### 01-executive-summary.md

| Section                   | Content                                                  |
| ------------------------- | -------------------------------------------------------- |
| **One-Sentence Goal**     | Clear statement of what and why                          |
| **Business Context**      | Problem being solved, market context                     |
| **Target Users**          | Personas with primary goals                              |
| **Success Criteria**      | How success will be measured                             |
| **Key Constraints**       | Timeline, budget, technology, compliance                 |
| **Critical Dependencies** | External systems, third parties, client responsibilities |
| **Risks Summary**         | Top 3-5 risks (detailed in 05-complexity-estimate.md)    |

### 02-requirements-matrix.md

Organize requirements by priority, then by category within each priority.

**Priority Framework:**

| Priority | Meaning                                    | Typical Source Language                 |
| -------- | ------------------------------------------ | --------------------------------------- |
| P0       | Essential - system doesn't work without it | "Required", "Must have", "MVP", "Pilot" |
| P1       | Must-have for target workflows             | "Needed for rollout", "Phase 2"         |
| P2       | Important, adds significant value          | "Should have", "Post-pilot"             |
| P3       | Nice-to-have, can defer                    | "Optional", "Future", "Nice-to-have"    |

**Table Format:**

```markdown
## P0 - Essential

| ID    | Category | Requirement             | Acceptance Criteria        | Dependencies             |
| ----- | -------- | ----------------------- | -------------------------- | ------------------------ |
| R-001 | Auth     | User can log in via SSO | SAML 2.0 integration works | Identity provider config |
| R-002 | Core     | ...                     | ...                        | ...                      |

## P1 - Must-Have

| ID    | Category  | Requirement | Acceptance Criteria | Dependencies |
| ----- | --------- | ----------- | ------------------- | ------------ |
| R-010 | Reporting | ...         | ...                 | ...          |
```

**Preserve original IDs** from source documents where available. If no IDs exist, generate sequential IDs (R-001, R-002, etc.).

**Include at end:**

- **Scope Exclusions** - What is explicitly NOT in scope
- **Ambiguous Requirements** - Items needing clarification
- **Dependency Graph** - Which requirements depend on others

### 03-technical-architecture.md

| Section                   | Content                                             |
| ------------------------- | --------------------------------------------------- |
| **System Overview**       | ASCII diagram showing major components              |
| **Component Breakdown**   | Table: Component, Responsibility, Technology, Phase |
| **Integration Points**    | External systems, APIs, data flows                  |
| **Data Flow Diagram**     | ASCII diagram showing how data moves                |
| **Security Architecture** | Auth, authorization, data protection approach       |
| **Infrastructure**        | Hosting, scaling, environments                      |
| **Technology Stack**      | Languages, frameworks, databases (if specified)     |

**ASCII Diagram Example:**

```text
┌─────────────────────────────────────────────────────────────┐
│                        Frontend                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Web App   │  │ Mobile App  │  │   Admin UI  │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
└─────────┼────────────────┼────────────────┼─────────────────┘
          │                │                │
          └────────────────┼────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway                             │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Backend Services                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    Auth     │  │    Core     │  │  Reporting  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  PostgreSQL │  │    Redis    │  │     S3      │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 04-data-model.md

| Section             | Content                                          |
| ------------------- | ------------------------------------------------ |
| **Entity Overview** | List of core entities with descriptions          |
| **ER Diagram**      | ASCII diagram showing relationships              |
| **Entity Details**  | For each entity: attributes, types, constraints  |
| **Relationships**   | Cardinality, foreign keys, indexes               |
| **Access Patterns** | Key queries the system will perform              |
| **Multi-tenancy**   | Data isolation approach (if applicable)          |
| **Compliance**      | Data retention, PII handling, audit requirements |

**ER Diagram Example:**

```text
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│   Tenant     │       │    User      │       │    Role      │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id (PK)      │───┐   │ id (PK)      │   ┌───│ id (PK)      │
│ name         │   │   │ tenant_id(FK)│◄──┘   │ name         │
│ settings     │   │   │ email        │       │ permissions  │
└──────────────┘   │   │ role_id (FK) │───────┤              │
                   │   └──────────────┘       └──────────────┘
                   │           │
                   │           │ 1:N
                   │           ▼
                   │   ┌──────────────┐
                   │   │   Project    │
                   │   ├──────────────┤
                   └──►│ tenant_id(FK)│
                       │ owner_id(FK) │
                       │ name         │
                       └──────────────┘
```

### 05-complexity-estimate.md

| Section                   | Content                                            |
| ------------------------- | -------------------------------------------------- |
| **Complexity by Module**  | Table: Module, Complexity (L/M/H), Reasoning       |
| **Risk Factors**          | Technical, schedule, scope, resource risks         |
| **Skill Requirements**    | What expertise is needed                           |
| **External Dependencies** | Third parties, client responsibilities             |
| **Open Questions**        | Items requiring answers before accurate estimation |
| **Cost Drivers**          | What makes this expensive or cheap                 |

**Complexity Rating Guide:**

| Rating | Meaning                                | Indicators                                   |
| ------ | -------------------------------------- | -------------------------------------------- |
| Low    | Well-understood, standard patterns     | CRUD operations, simple integrations         |
| Medium | Some unknowns, moderate complexity     | Custom business logic, multiple integrations |
| High   | Significant unknowns, novel approaches | AI/ML, complex algorithms, many integrations |

### 06-implementation-phases.md

| Section               | Content                                                  |
| --------------------- | -------------------------------------------------------- |
| **Phase Overview**    | Table: Phase, Duration, Goals, Key Deliverables          |
| **Phase Details**     | For each phase: goals, requirements, tasks, dependencies |
| **Milestone Markers** | Key decision/review points                               |
| **MVP Definition**    | What constitutes minimum viable product                  |

**Phase Detail Format:**

```markdown
## Phase 1: MVP / Pilot

**Goals:**

- <goal 1>
- <goal 2>

**In-Scope Requirements:** R-001, R-002, R-003, R-010, R-011

**Deliverables:**

- [ ] <deliverable 1>
- [ ] <deliverable 2>

**Tasks:**

- [ ] Set up project infrastructure
- [ ] Implement authentication (R-001)
- [ ] Build core data model
- [ ] ...

**Dependencies:**

- <what must be ready before this phase>

**Success Criteria / Go-No-Go:**

- <how we know this phase succeeded>
```

---

## Priority Framework (Mapping Source Language)

When source documents use different terminology, map to P0-P3:

| P0 (Essential) | P1 (Must-Have)       | P2 (Important)    | P3 (Nice-to-Have) |
| -------------- | -------------------- | ----------------- | ----------------- |
| "Required"     | "Needed for rollout" | "Should have"     | "Optional"        |
| "Must have"    | "Phase 2"            | "Post-pilot"      | "Future"          |
| "MVP"          | "Full deployment"    | "Enhancement"     | "Could have"      |
| "Pilot"        | "Scale"              | "Improvement"     | "Stretch goal"    |
| "Critical"     | "High priority"      | "Medium priority" | "Low priority"    |
| "Blocking"     | "Important"          | "Desired"         | "Wishlist"        |

---

## Validation Checklist

Before completing, verify:

- [ ] README.md links to all 6 documents
- [ ] Source documents copied to `source-docs/`
- [ ] One-sentence goal is genuinely one sentence and captures the "why"
- [ ] All requirements have IDs (original or generated)
- [ ] Requirements mapped to priorities (P0/P1/P2/P3)
- [ ] ASCII diagrams render correctly in markdown preview
- [ ] No placeholder text (`[TBD]`, `[TODO]`, `<insert>`)
- [ ] Implementation phases have unchecked task lists
- [ ] Open questions documented in 05-complexity-estimate.md

---

## Important Notes

- **Scope boundary:** This skill produces ANALYSIS, not DESIGN. If you find yourself designing APIs, writing code, or creating detailed component specs, stop. That's the job of `/spec`.
- **Preserve original IDs:** If the source document has requirement IDs, use them. Don't renumber.
- **Be specific:** Reference actual content from documents, not generic placeholders.
- **Note ambiguity as risk:** When documents are unclear, note the ambiguity in 05-complexity-estimate.md.
- **One-sentence goal matters:** If you can't express the goal in one clear sentence, the project scope is probably unclear.
- **Appendices are exceptions:** Only create `A1-*.md` files when information doesn't fit any of the 6 standard documents AND is critical for planning.

---

## Example One-Sentence Goals

**Good:**

- "Build an internal platform where human workers can label data at scale, with ops teams managing workflow from task ingestion to customer delivery."
- "Commercialize an internal AI documentation tool as a multi-tenant SaaS product, starting with a single pilot customer before scaling to enterprise rollout."
- "Create a customer portal for submitting support tickets, tracking status, and accessing self-service knowledge base articles."

**Bad:**

- "Build a good system for handling things." (too vague)
- "Implement all features in the PRD." (circular)
- "Respond to the RFQ requirements." (describes the document, not the goal)
