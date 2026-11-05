# Work state templates

Use only the fields the work needs; do not add sections for their own sake.

## Task record

```markdown
# <observable outcome>

Goal and source: <request/contract link or concise requirement>
Checkout: <absolute path>; branch <branch>; base <revision>; current <revision and dirty patch>
Authority and stop boundary: <allowed actions and where this task stops>
Status and next action: <what happens next, owner, and any wait>

Decisions and assumptions:
- <who decided what, why, source; type; supersedes; evidence for consequential input assumptions>

Gates:
- <claim>: <passed/failed/blocked/pending>; <tested revision/build/environment>;
  <exact command/result and runnable fixture/output paths>; <limits or applicability to current code>

Review:
- <finding, source, disposition and evidence, or outstanding decision>

Pending questions:
- <question, what it blocks, attempts, recommendation; open | answered with the dated verbatim answer>

Publication, if authorized: <PR URLs, pushed heads, watcher ownership and outstanding checks>
```

## Ledger

### `STATE.md`

```markdown
# <project / topic>: current state

Ledger: <absolute path of this directory>
Goal and scope: <one paragraph or link to the project/epic>
Authority: <active authority and temporary exceptions by decision ID, e.g. D-003 (expires 2026-11-06)>
Last reconciled: <UTC time> against <sources checked: MRs, pipelines, tickets, worker threads>

## Workstreams

| ID | Outcome | Owner thread | Task record | Branch / MR | Head SHA | Status | Blocked by | Next action |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| W1 | <observable outcome> | <thread link> | <absolute path> | <branch> / <MR link> | <sha> | <state> | <W/Q/D id or external> | <who does what next> |

## Blockers

- <blocker, owner, since when, what unblocks it>

## Next actions

1. <action, owner>
```

### `decisions.md`

```markdown
# Decisions

## D-001: <short title>

- Date: <YYYY-MM-DD>; decided by: <person>; type: <product | authority | scope | temporary exception | technical>
- Statement: <the decision, in one or two sentences>
- Source: <link to the message, ticket, MR note or document, with position or quote>
- Scope / expiry: <where it applies; when it ends>
- Supersedes: <D-id or none>; superseded by: <D-id or none>
- Shared copy: <repo doc, ADR, ticket or none>
- Status: <active | superseded | expired>
```

### `inbox.md`

```markdown
# Inbox

## Q-001: <question in one line>

- Asked: <YYYY-MM-DD HH:MM UTC> by <thread link>; blocks: <W/D ids or work>
- Context: <what the user needs to answer without the transcript: facts, links, constraints>
- Options: <A, B, ...>; recommendation: <option and why>
- Status: <open | answered | withdrawn>
- Answer: <verbatim, dated>; recorded as <D-id>
```

### `log.md`

```markdown
# Log

- <YYYY-MM-DD HH:MM UTC> <event: launched W3 / merged !123 at sha / D-007 superseded by D-012 / reconciled> <links>
```
