# aidev-toolkit Philosophy

> **Status: draft.** Wording is to be confirmed by the maintainer. The first two principles were stated directly by the maintainer on 2026-11-16, and the third, fourth and fifth on 2026-11-17. The rest are carried over from rules already in this repo and are marked as such.

This document says why the toolkit is built the way it is. The architecture principles in `architecture-principles/` say what a codebase must do. This document sits above them.

## 1. Stable, and always evolving

The framework and harness should be stable and also always evolving.

- **Stable** means the things people rely on behave predictably: slash commands, the installer, the guards, the file layout.
- **Evolving** means the toolkit keeps changing as we learn. Change arrives through specs and releases (`/aid-update`), not through ad hoc edits.

These pull against each other. Stability is what makes evolution safe, and evolution is what keeps stability from turning into stagnation.

## 2. If we want it, the tool enforces it

Any principle we want to support or enforce must be built into the tool itself. A philosophy without a mechanism to enforce it is not good enough.

This applies equally to:

- architectural principles
- design goals
- anything we want an individual to do
- anything we want the team to do collectively

A principle is only real here when something in the tool carries it: a skill, a hook, a guard, a check in `/arch-review`, or a test. If no mechanism exists, the principle is a wish, and the gap becomes a spec.

## 3. The repo holds the whole story

The source repo contains everything you need to know about the project. Nobody should have to go anywhere else for anything specific to this project.

That includes all project management material: scheduling, risk management, source code, design, decisions, and status. The repo should hold the entire story. Context is king.

It is the job of the maintainer, human and AI alike, to keep this information organized so that decisions can be made clearly and intelligently. Material that exists but cannot be found, or is scattered across chat threads, tickets and private notes, does not count as context.

Enforcement: no mechanism identified yet. Candidates are an `/arch-review` check that scheduling, risk and decision records exist and are current, and a check that `specs/README.md` status matches the specs.

## 4. The repo is connected to every source of project context

Principle 3 only holds if the repo is connected to the places where project context originates. Communication with outside parties, and the de facto decisions made in it, happen in:

- email (Gmail)
- chat (Google Chat, Teams, Slack, and so on)
- meeting recordings and summaries (Fathom)

All of it is context for the decisions being made. It must be recorded in the repo in a way that is defensible: each record keeps its source, its date and time, and who said it, and is stored unaltered or with clearly marked summaries. The test is reconstruction: given only the repo, you could rebuild the timeline of what was said, what was decided, and why.

Where a decision is made in a channel, the maintainer, human or AI, records it in the repo and links it back to the source.

Enforcement: partial. The toolkit already has readers for these sources (`/gmail-digest`, `/gchat`, `/fathom`, feedback ingest), but nothing yet writes their content into the repo as a durable, dated record. That gap becomes a spec.

## 5. Safety rules combine so the most restrictive wins

When rules exist at more than one level (user, project, team), a safety rule is never loosened by a more specific level. Layers can add blocks. They cannot remove one.

- **Deny anywhere wins.** If any level blocks something, it is blocked.
- **Exceptions come from the owner.** Only the level that set a block can grant an exception to it. A project may ask for an exception; the user level grants it.
- **Why.** The user level is the machine's owner. The project level comes from a repo the user may not have written, so letting it override a safety rule would let a hostile repo switch the rule off. "The most specific level wins" suits preferences (formatting, model choice), not safety.
- **Consequence.** Two overlapping guards produce the union of their blocks, so the stricter or buggier one decides the outcome. A false positive fixed at one level stays in force while another level still blocks. See `specs/spec-v136-guard-hook-not-installed-by-default.md`.

Enforcement: none yet. Candidates are a documented layering rule in each toolkit hook and config, and a test that a project-level setting cannot loosen a user-level block.

## 6. Principles carried over from existing rules

These come from rules already stated elsewhere in the repo. They are included so they can be reviewed against principle 2. They are not newly decided.

| Principle | Source | Enforcement mechanism |
| --------- | ------ | --------------------- |
| Simplicity: perfection is achieved when there is nothing left to take away | `specs/spec-v83-architect-skill.md` | Not audited |
| Nothing is done until validated by tests | `CLAUDE.md` (Definition of Done) | Not audited |
| No mocks in tests | `CLAUDE.md` | Not audited |
| Destructive commands are blocked | `docs/destructive-command-guard.md` | `scripts/guard-destructive-commands.py` |
| The source repo is the truth; `~/.claude` is only a deployment target | `CLAUDE.md` | Not audited |
| Work products go in project-visible folders, never `.claude/` | Maintainer, 2026-11-16 | None known |

"Not audited" means nobody has checked yet whether a mechanism exists. It does not mean there is none.

## Open items

- Confirm or reword the five stated principles.
- Decide how principle 5 is enforced, and check that each toolkit hook and config follows it (it has no mechanism yet).
- Decide how principle 3 is enforced (it has no mechanism yet, so under principle 2 it is a wish).
- Spec the capture of email, chat and Fathom content into the repo (principle 4).
- Decide how to handle sensitive or third-party content in recorded communications: repo visibility, redaction, and retention.
- Run the enforcement audit: for each row above, name the mechanism or open a spec to build one.
- Decide how this document relates to the group standard being scoped in `specs/spec-v135-ai-dev-patterns-standard.md`.
