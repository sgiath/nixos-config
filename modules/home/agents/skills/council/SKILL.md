---
name: council
description: "Use when the user says 'council': four models from different providers (each in its native harness) review the current change, or advise on a question, in parallel rounds until all of them approve."
---

# Council

Get independent review from four model providers at once, each in its native harness. The
invocation authorizes the review rounds and fixes to findings within the task's scope; it adds no commit, push,
publication or merge authority.

## Members

Use the members the user names, always in each provider's native harness. Otherwise:

| Provider instance | Model | Effort option |
| --- | --- | --- |
| `codex` | `gpt-6.2-sol` | `reasoningEffort: high` |
| `claudeAgent` | `claude-opus-5-5` | `effort: high` |
| `antigravity` | `gemini-4-neon` | `thought_level: high` |
| `grok` | `grok-4.7` | `reasoningEffort: high` |

Resolve exact IDs and options with `orchestrator_capabilities`. If a member is unavailable, report it and ask how
to proceed; do not substitute another model or harness.

## Rounds

Write one brief from verified-work's [review brief](../verified-work/references/independent-review.md) and follow
its review rounds: preparation, fixed scope, read-only reviewers, severities, ledger, budget and stop rules. In
addition, ask each member for a score out of 10.

Start one `delegate_task` per member in parallel and yield until all four return. Merge their findings: drop
duplicates, record which members raised each one and where they disagree. A finding stands or falls on its
evidence, not on how many members raised it. Production fixes follow verified-work's role routing. Each round
goes to every member as a new `delegate_task`, because a member's earlier approval does not cover the changed diff.

Four reviewers grow scope faster than one. Hold the change to the task; declined findings become follow-ups.

When the user asks for advice instead of a code review, give each member the question and context, skip fixes to
code that the question may replace, and summarize the useful findings, disagreements and your recommendation.

## Report

Report in the final reply: rounds, a score table with one row per member and one column per round (`no score`
when a member gave none), fixed and declined findings with reasons, and open disagreements. Do not put the table
or model credits in a PR description or comment written in the user's name.
