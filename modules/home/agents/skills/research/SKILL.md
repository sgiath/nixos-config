---
name: research
description: "Use when asked to research a question and save a source-cited repository note."
---

Split independent research angles between subagents when useful; keep a narrow lookup in one context.

Use fresh context, not forked context, unless the user explicitly asks otherwise. Delegated researchers should inspect sources directly instead of relying on the main conversation history.

In T3, discover models through `orchestrator_capabilities` and use native subagents where supported or `delegate_task`
for cross-provider/T3-owned work. Supply the question, source pointers and output contract explicitly. Retain async
task IDs and yield for completion notifications; do not create separate top-level threads to obtain fresh context.

Give delegated agents task-specific briefs rather than requiring named agent types:
- External research: official docs, standards, ecosystem changes, benchmarks and primary-source evidence.
- Codebase research: local implementation patterns, repository constraints and affected files.

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs and academic papers — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. *Practical tradeoffs* - compare options, risks, edge cases, maintenance cost, and what would be easiest to validate.

Adapt the angles when the question calls for it:
- Library/API questions: include official docs and recent examples.
- Architecture decisions: include local module boundaries, dependency direction, and migration cost.
- Debugging questions: include likely failure modes, local call paths, and exact error evidence.
- UI/product questions: include user flow, accessibility, design precedent, and implementation constraints.
- Time-sensitive topics: include a recent-developments angle and prefer current sources, checking their publication date and applicable version.

## Result

Write the findings to a single Markdown file, citing each claim's source. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it in `.agents/research/`
