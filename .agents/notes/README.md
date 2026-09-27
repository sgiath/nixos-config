# Agent Notes

Agent Notes are durable proposals and decision records for NixOS configs. They preserve why a change was proposed or chosen, the alternatives considered, the consequences, and the verification needed to revisit the decision safely.

Canonical product behavior remains under [`README.md`](../../README.md). Product documentation explains how the current system behaves and is used. Agent Notes explain why a proposal or decision exists and what it gave up.

## Layout and naming

Active notes use `{lifecycle}/{class}/yyyy-mm-dd-topic.md`:

- `proposed/` contains work that has not shipped or has only partly shipped.
- `implemented/` contains current shipped decisions whose rationale remains useful.
- `rejected/` contains declined proposals only while their rationale prevents a plausible mistake.
- `archived/` contains frozen historical records of implemented work that is not current authority.

The date is when the topic was first proposed. Cross-references use relative Markdown links so lifecycle moves remain mechanically discoverable.

The filesystem tree is the inventory. Do not add a centralized `INDEX.md`; browse lifecycle and class directories or search the repository.

### Lifecycle moves ship with the code

By default, a change that implements a proposed note also moves that note to `implemented/` in the same commit series and pull request. In the same change, rewrite the note in the implemented format and repair every link to it. Do not wait for merge or deployment to move it. If the pull request is not merged, the move is discarded with it. If it is merged, the tree describes the code that actually shipped.

When the change implements only part of a note, move the implemented part and leave the unfinished work in a proposed note, split or updated. Operational follow-ups such as deployment or an authorized production run are not unfinished code. Record them in the implemented note's consequences, or link to the proposed note that owns them.

## Classification

Every note belongs to one path-encoded class:

| Class            | Scope                                                           |
| ---------------- | --------------------------------------------------------------- |
| `feature`        | A user- or model-facing capability.                             |
| `bug-fix`        | A defect correction or reliability hardening.                   |
| `simplification` | Removal or reduction of code, behavior, or surface area.        |
| `architecture`   | Structure, runtime boundaries, protocols, and shared contracts. |
| `process`        | Tooling, policy, documentation, and contributor workflow.       |
| `testing`        | Test infrastructure and strategy.                               |

The folder is the classification. Do not repeat it as document metadata or introduce ad hoc classes.

## When to write a note

Write or update an Agent Note when future maintainers are likely to revisit a proposal, trade-off, ownership boundary, compatibility contract, security rule, or negative guarantee. Routine local changes and facts already explained by code and canonical documentation do not need a note.

Findings outside the current task are not fixed in that change. A small or routine finding gets a `FIXME:` comment at the affected code instead of a note. A finding whose fix would touch multiple files or change architecture gets a `proposed/` note.

Search active notes before creating one. Update the note that owns an existing decision rather than duplicating it. A changed decision gets a new note and cross-links to the old one; factual paths, names, and mechanisms may be updated in an implemented note without changing its rationale.

Every new note triggers a supersession check. Keep partial supersessions active and cross-linked. Fully superseded notes may be archived after the current owner preserves their unique rationale, alternatives, consequences, and verification.

## File format

Every active note starts with:

```markdown
# Agent Note: <title>

Status: <status>
```

The status is exactly the lifecycle directory name (`rejected` adds ` - <reason>`). Implementation progress, deployment state, and caveats never go on the status line; a partly implemented note is split as described in [Lifecycle moves ship with the code](#lifecycle-moves-ship-with-the-code).

### Proposed

```markdown
## Problem

## Proposal

## Alternatives considered

## Acceptance criteria

## Risks
```

Plans, migration steps, and open questions belong in proposed notes.

### Implemented

```markdown
## Problem

## Decision

## Alternatives considered

## Consequences
```

Implemented notes describe shipped reality in the present tense. They may include current technical contracts and verification, but not proposal-era `Proposal`, `Plan`, `Migration plan`, or `Acceptance criteria` sections. Move independent unfinished work into a proposed note.

### Rejected

Rejected notes use `Status: rejected - <reason>` and retain the proposal that was declined. They require `Problem`, `Proposal`, and `Alternatives considered` sections.

### Bug fixes

Notes under `bug-fix/` use a shorter format. Proposed bug-fix notes require `Problem`, `Proposal`, and `Acceptance criteria`; implemented bug-fix notes require `Problem`, `Decision`, and `Verification`. Add `Alternatives considered` (and `Risks` to a proposed note) only when a real alternative was weighed.

## Archiving

Only implemented work may be archived. Archived notes use `Status: implemented` followed by `Archived: YYYY-MM-DD` and live at `archived/{class}/yyyy-mm-dd-topic.md`.

Archived notes are frozen historical snapshots and are not current authority. Do not update their facts, repair their outbound links, reformat them, or use them instead of canonical product documentation.

Files migrated from a former planning tree may retain their implementation checklists and historical structure when sealed. Unchecked boxes in those snapshots record their state at the time and are not an active backlog; migration must extract still-owned work into proposed notes. Archive metadata and paths provide lifecycle and classification without fabricating rationale that was not recorded at the time.

## Relationship to canonical docs

- Current behavior, public contracts, operator workflows, and failure modes belong in `README.md`.
- Decision rationale, rejected alternatives, trade-offs, and reintroduction conditions belong here.
- Incident chronology belongs in debugging or postmortem documentation.
- Procedures belong in development documentation or a skill.

An implemented note stays factually current enough for its rationale to remain intelligible, but canonical product documentation remains the complete authority for current behavior.
