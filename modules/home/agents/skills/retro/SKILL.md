---
name: retro
description: "Use for /retro or an explicit request for a retrospective on one or more agent sessions."
disable-model-invocation: true
---

# Retro

Review agent sessions and propose changes to the agent's **environment** that make the next run cheaper and more reliable: steering files, skills, checks, tooling, and information access. Do not change the code the session worked on, and do not apply any proposal until the user picks it. Agents rarely report the friction they pushed through, so judge from the session record, not from the agent's final summary.

## 1. Read the sessions

Default to the current session when the user names none. Otherwise find the requested sessions by project directory,
date, or topic. Inside T3, start with its thread search/read tools: resolve the project, search titles/content, then
read the matching durable timelines, including relevant tool activity and child work. Paginate with the returned
cursor/position and recover truncated item text before drawing conclusions. Search is bounded to active threads and
is not exhaustive: use filtered/paginated thread lists (including settled threads when relevant) to broaden coverage.
Use provider session files when T3 history lacks needed tool evidence or the requested work happened outside T3;
deduplicate mirrored transcripts by task, timestamps and message evidence. Session stores:

- Claude Code: `~/.claude/projects/<cwd-with-dashes>/*.jsonl`
- oh-my-pi: `~/.omp/agent/sessions/<cwd-slug>/` (default profile) and `~/.omp/profiles/<profile>/agent/sessions/<cwd-slug>/` (for example `crazyegg`, `remote`); check every profile, since one project can have sessions in several
- Codex: `~/.codex/sessions/<yyyy>/<mm>/<dd>/*.jsonl`
- pi: `~/.pi/agent/sessions/<cwd-slug>/`
- T3 Code threads: search and read them with the T3 thread tools

Worktree checkouts get their own directory slug (`core_v2.feat-x`), so include them when collecting a project's
sessions. For large sets, split sessions between subagents that return findings with thread ID/item or session
path and message evidence; read transcripts, not just final summaries. Supply explicit source IDs/paths and read-only
briefs. In T3, async delegated completion wakes the parent; yield instead of polling. Do not create top-level review
threads merely to delegate a retrospective.

Also read the steering the session ran under: the global `AGENTS.md` (source: `~/nixos/modules/home/agents/AGENTS.md`), the repository `AGENTS.md`/`CLAUDE.md`, the skills it loaded (source: `~/nixos/modules/home/agents/skills/`), and the repository's check commands and CI workflows.

## 2. Look for candidates

- **Navigation**: the agent took long to find a file, module, or fact, or missed a hidden dependency between files. Propose a pointer in the nearest steering file, a `CONTEXT.md` entry, or a code comment at the place it looked first.
- **Automated checks**: the agent made a mistake that a formatter, linter, type check, test, or CI job could catch. First read the repository's existing check commands and CI; a check that exists but is not wired into a hook or CI, or is silently broken, is the finding. A repository with no guardrail at all is a finding by itself.
- **Coding standards**: the CI reviewer missed a mistake or enforced a wrong rule. Classify the rule first. A mechanical rule (banned API, import shape, file location, fixed pattern) gets a deterministic check in the repository's own linter, hook, or CI. Only a judgement call (cross-file consistency, matching surrounding style) goes into the reviewer's instructions. Reviewers read a diff with little context pressure, so standards belong there rather than in the implementer's steering.
- **Steering files**: instructions in `AGENTS.md` or a skill that the agent ignored, that never changed behavior (**no-ops**), that contradict each other, or that belong in a check, reviewer rule, or on-demand doc instead of always-loaded context. Skills whose description fails to trigger when needed, or triggers when not.
- **Tool economy**: expensive or repeated tool calls, oversized outputs, polling loops, custom CLIs or MCP tools that waste tokens, work redone after compaction.
- **Information access**: something the agent needed and could not get (logs, service state, credentials it had to ask for, read-only access to a third-party system), or instructions repeated by the user in several sessions that should live in a skill.
- **Unsafe actions**: irreversible or outward-facing actions taken without confirmation, and what guardrail would have stopped them.

## 3. Report

Present the candidates ordered by severity. For each: what happened (thread/item or session path and short quote or
tool-call evidence), the proposed environment change with the exact file it touches, and whether it is a check,
reviewer rule, steering edit, skill change, or tooling change. State history-coverage limits. Note rejected likely
false positives briefly. Then stop and let the user choose; record accepted multi-file changes as proposed notes
in `.agents/notes/` when the user wants them tracked instead of done now.
