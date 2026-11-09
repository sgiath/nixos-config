# Agent Note: Enforce work-state records with agent hooks

Status: proposed

## Problem

The [work-state](../../../../modules/home/agents/skills/work-state/SKILL.md) skill keeps task records and ledgers
in `$XDG_STATE_HOME/agent-work/`, but every step that makes them useful depends on the model remembering a rule:

- **Finding the record.** A resumed or compacted session finds its record only if the compaction summary or the
  thread kept the absolute path. Nothing outside the transcript links a session to its record.
- **Keeping it current.** The skill says to update the record before a manual compaction. The model cannot predict
  automatic compaction, so the record is only as current as the last update the model remembered to make.
- **Keeping questions visible.** "End each message with the open questions" is the rule written after the Spain
  G2N sprint, where questions were lost among worker reports
  ([coordinator-secretary](2026-11-05-coordinator-secretary.md#problem)). It still relies on memory.
- **Checking the baseline on resume.** Resumption checks git, PR and pipeline state but never re-runs a cheap
  check, so new work can start on a broken baseline.
- **Restoring the environment.** Records list gate commands, but not how to restore the environment and confirm
  it works.

Anthropic's
[Effective harnesses for long-running agents](https://www.anthropic.com/research/effective-harnesses-for-long-running-agents)
solves the same problems with a progress file at a fixed location that every session reads first, an `init.sh`
that restores the environment, a quick end-to-end check before new work, and a session end in a clean state
(committed, progress updated). Its harness does these things itself instead of relying on the model.

## Proposal

Have Claude Code hooks do what the skill now asks the model to remember. One script, merged into
`settings.json` by the existing jq activation in
[`claude.nix`](../../../../modules/home/agents/claude.nix), with four entry points:

| Hook                                                    | Behavior                                                                                                     |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| PostToolUse on Write/Edit of a file under `agent-work/` | Saves a link from the session to that record directory. Binding happens only on **write**.                   |
| SessionStart, matcher `compact\|resume`                 | If the session has a linked record, adds the record to the context (see the role table below).               |
| Stop (skipped when `stop_hook_active` is set)           | Checks file facts only and stops the agent with a one-line reason when one fails (see the role table below). |
| SessionStart, matcher `startup` (optional)              | Lists open records whose `Checkout:` matches the current directory, one line each.                           |

### Coordinator and worker

Every session gets the same hook. Behavior depends on the kind of record the session is bound to, not on a role
flag; T3 does not tell a hook whether a thread is a coordinator or a worker. Binding on write separates the roles
without a flag: the skill already makes the coordinator the only writer of the ledger, and workers only read it.
A directory with `STATE.md` and `inbox.md` is a ledger; a single record file is a task record.

|                                     | Coordinator (bound to a ledger)                                                        | Worker (bound to a task record)                                                                             |
| ----------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| After compaction or resume, it gets | `STATE.md`, active decisions, open `inbox.md` questions                                | Its task record, plus the current status of each decision ID in its `Relies on:` line, read from the ledger |
| Stop: checkout check                | None, because the ledger has no single checkout                                        | Stops the agent if HEAD or the working tree changed after the record was last written                       |
| Stop: open questions                | The last message must list the open inbox question IDs, because those are for the user | Its final report must list its pending questions, because those go to the coordinator                       |
| Unbound session                     | Nothing                                                                                | Nothing, so small tasks pay no cost                                                                         |

The hook does not check whether `STATE.md` reflects the worker reports that have arrived. It cannot tell that from
files without parsing those reports from the transcript, and guessing would keep stopping the coordinator for
nothing. Live reconciliation belongs to the [secretary](2026-11-05-coordinator-secretary.md)'s
`status.generated.md`.

### Skill changes

- Add a few fixed-format lines the hooks can parse: `Checkout:`, `Status: open|closed`, question IDs with their
  status, and `Relies on: D-<id> (<ledger path>)` in a worker's task record, which comes from its brief.
- Add a **Resume** field to the task record: the commands that restore the environment and the cheapest check that
  proves the baseline still works (the article's `init.sh`).
- Change the resumption rule: run that check before any new work, and if it fails, fix that first.

## Alternatives considered

- **Keep the rules model-only (current state).** No code to maintain, but every failure listed in Problem stays
  possible, and the Spain sprint showed the question rule failing under load.
- **Separate coordinator and worker hooks, or a role environment variable.** T3 launches do not tell the hook the
  thread's role, and a flag set in the brief can be dropped. Binding on write uses the ledger's single-writer
  rule, which already exists.
- **Store the state as JSON, as the article does for its feature list.** It resists rewriting by the model, but the
  user edits these files and reads them as an audit trail. A hook that rejects edits to a recorded gate's claim
  would give the same protection and keep the Markdown.
- **A PreCompact hook that updates the record.** A hook cannot make the model write before compaction. Re-adding
  the record on `compact` plus the Stop-time staleness check covers the same failure.
- **The article's separate initializer session.** verified-work and drive already set the gates up front.

## Acceptance criteria

- A failing reproduction first: a session that wrote a task record, then is compacted, does not have the record's
  path or contents in its context today. With the hooks, it does.
- A worker whose `Relies on:` cites a decision superseded since its brief is told so on resume.
- The Stop hook stops a worker whose checkout's HEAD or working tree changed after its record was last written,
  and does not stop it again when `stop_hook_active` is set.
- work-state's `question-survival` eval, extended to ten worker events, passes with the hook enforcing the
  open-question list.
- Unbound sessions see no added context and are never stopped.
- The hooks load in sessions T3 launches through the SDK, not only in the terminal CLI.

## Risks

- **Native subagents.** A Claude Code subagent's hook calls probably carry the parent's `session_id`. If so, a
  subagent writing a record would bind the parent session to it. Bind by agent ID when the hook input has one, or
  ignore subagent calls. Not verified. `delegate_task` children are separate T3 threads and do not have this
  problem.
- **Codex.** Workers are mostly Codex under the model routing, so the worker column depends on whether Codex hooks
  can do SessionStart, Stop and context injection the same way. Not verified. If they cannot, the Claude hook still
  covers the coordinator side, and Codex workers keep following the rules by hand.
- **Excess stops.** A Stop check that fires on facts the model cannot fix (a working tree changed by another
  session in a shared checkout such as `~/nixos`) would loop or annoy. Compare against the record's own
  `Checkout:` revision and limit the check to paths the session itself changed where possible.
- **Context size.** Re-adding a large ledger on every resume costs tokens. Add the current state, active decisions
  and open questions only, never `log.md`.
- **Overlap with the secretary.** The Stop open-question check covers part of the
  [coordinator-secretary](2026-11-05-coordinator-secretary.md) acceptance criteria. Keep this hook to file checks
  and leave event intake and live status to the secretary.
