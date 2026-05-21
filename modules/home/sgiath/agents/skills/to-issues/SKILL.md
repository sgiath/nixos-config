---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable Backlog.md tasks using tracer-bullet vertical slices. Use when user wants to convert a plan into tasks, create implementation tickets, or break down work into Backlog.md tasks.
---

# To Issues

Break a plan into independently-grabbable Backlog.md tasks using vertical slices (tracer bullets).

Use Backlog.md for task tracking. Prefer the `backlog` CLI and plain output for agent work.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a task reference (`task-7`, `7`, URL, or path) as an argument, fetch it with `backlog task view <id> --plain` and read the full task body, plan, notes, acceptance criteria, labels, and dependencies.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Task titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft vertical slices

Break the plan into **tracer bullet** tasks. Each task is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?

Iterate until the user approves the breakdown.

### 5. Publish the tasks to Backlog.md

For each approved slice, publish a new Backlog.md task. Use the task body template below. These tasks are considered ready for AFK agents, so keep status `todo` and apply the `ready-for-agent` label unless instructed otherwise.

Publish tasks in dependency order (blockers first) so later tasks can use real Backlog dependency identifiers.

Create each task with `backlog task create`:

- Title: the slice title.
- Description: the "What to build" content.
- Acceptance criteria: repeat `--ac` once per criterion.
- Status: use `--status todo` unless the task is already in active work or already complete.
- Labels: include `enhancement` or `bug`, plus `ready-for-agent` unless a different triage state is requested.
- Dependencies: use `--dep task-1,task-2` for blocking tasks.
- References/docs: use `--ref` and `--doc` for source plan, PRD, issue, or design links.
- Plain output: add `--plain` when useful for reliable parsing.

Avoid shell-specific newline tricks. For multi-line text, either pass real newlines inside quotes or create/update the task, then append notes line-by-line with `backlog task edit <id> --append-notes "..."`.

<issue-template>
## Parent

A reference to the parent Backlog task, source issue, plan, or PRD (if there is one, otherwise omit this section).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

Avoid specific file paths or code snippets — they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it here and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- A reference to the blocking Backlog task (if any)

Or "None - can start immediately" if no blockers.

</issue-template>

Do NOT close, archive, or modify any parent task.
