---
name: to-issues
description: Break a plan, spec, or PRD into short, independently-plannable Backlog.md tasks using tracer-bullet vertical slices. Use when user wants to convert source material into task intents for later planning.
---

# To Issues

Break source material into short, independently-plannable Backlog.md tasks using vertical slices (tracer bullets).

This is not the full planning agent. Capture the task intent, enough context to preserve why it exists, and lightweight acceptance signals. Always capture provenance: where the task came from and where a planning agent can find more context. Leave detailed implementation plans, documentation strategy, modified-file tracking, and full Definition of Done design to the later planning/implementation workflow.

Use Backlog.md for task tracking. Prefer the Backlog MCP tools when available; otherwise use the `backlog` CLI with structured fields and plain output for agent work.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a task reference (`task-7`, `7`, URL, or path) as an argument, fetch it with `backlog task view <id> --plain` and read the full task body, plan, notes, acceptance criteria, labels, and dependencies.

Identify the source and context trail before drafting tasks:

- Parent or source Backlog task, if any.
- Current milestone or project initiative, if any.
- Source plan, PRD, spec, issue, conversation, ADR, or decision record.
- Existing documentation or docs directory where the planning agent should look for background.
- Related tasks, blockers, follow-ups, or dependencies.

Every created task must include enough provenance that a later planning agent can answer: "Why does this task exist, what larger effort does it belong to, and where do I read more?"

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Task titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

### 3. Draft vertical slices

Break the source material into **tracer bullet** tasks. Each task is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

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

For each approved slice, publish a new Backlog.md task using structured Backlog fields. Do not create your own Markdown issue template inside the description. The task should be ready for a planning agent, not already fully planned.

Publish tasks in dependency order (blockers first) so later tasks can use real Backlog dependency identifiers.

Use MCP `task_create` / `task_edit` fields when available. If using the CLI, create each task with `backlog task create`:

```bash
backlog task create "<slice title>" \
  --description "<short intent and desired outcome for this slice>" \
  --status todo \
  --labels "enhancement,needs-planning" \
  --parent "<parent-task-id>" \
  --dep "<blocking-task-ids>" \
  --notes "<provenance, source mapping, context links, assumptions, and constraints>" \
  --ac "<lightweight acceptance signal>" \
  --ref "<source plan, PRD, issue, ADR, or design reference>" \
  --plain
```

Omit fields that do not apply. Use `--parent` for the parent Backlog task when one exists. Use `--dep` / `--depends-on` only after blocker tasks have been created and their real task ids are known.

Use structured fields this way:

- **Title:** short slice name, using project domain language.
- **Description:** short intent and desired outcome. No sectioned issue template and no implementation plan.
- **Acceptance criteria:** repeat `--ac` for a few lightweight signals that show the slice intent was satisfied. Do not turn this into a full test plan.
- **Notes:** provenance, source mapping, current milestone or initiative, where to find more context, assumptions, open questions, HITL/AFK classification, and constraints.
- **Dependencies:** `--dep` / `--depends-on` for blocking Backlog tasks.
- **References:** `--ref` for source tasks, plans, PRDs, external issues, ADRs, decisions, designs, milestones, or documentation paths.
- **Definition of done:** usually rely on project defaults. Add `--dod` only for exceptional completion requirements known from the source material.

Do not set these fields from this skill:

- `--plan`: planning belongs to the write-plan skill or planning agent.
- `--doc`: documentation strategy belongs to the planning/implementation workflow.
- `--modified-file`: touched files should be recorded after implementation or during detailed planning, not guessed here.

Avoid shell-specific newline tricks. For multi-line text, either pass real newlines inside quotes or create the task first and then use `backlog task edit <id> --append-notes "..."`, repeated as needed.

Do NOT close, archive, or modify any parent task.
