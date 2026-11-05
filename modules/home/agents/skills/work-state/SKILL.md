---
name: work-state
description: "Use when work must survive a context compaction, a wait or a handoff: keep a task record for one substantial change, or a ledger when one thread coordinates several tasks, threads or merge requests across days. Records current state, decisions with supersession and the user's pending questions in files instead of the transcript. A small immediate edit needs neither."
---

# Keep work state outside the transcript

Context is lost at compaction, at resumption and at every handoff, and copies of decisions in briefs, tickets and
docs go stale. Keep the state that the next context needs in files, and treat the transcript as replaceable.

## Choose the shape

- **Nothing:** a small immediate edit that finishes in this context.
- **Task record:** one substantial change that will cross a context boundary, wait or hand off. One file.
- **Ledger:** one thread coordinating several tasks, threads or merge requests across days, with scope that keeps
  changing. Four files. Each worker keeps its own task record, and the ledger links to it.
- **A `drive` plan:** keep Drive's state directory; `plan-status` parses its files. Apply the decision and question
  rules below to Drive's `answers/`, `asked/` and `gates/` records instead of creating a parallel ledger.

Reuse a task's existing plan or state when it already holds this information.

## Where it lives

`${XDG_STATE_HOME:-$HOME/.local/state}/agent-work/<repository or project>/<task or topic>/`. Give concurrent tasks
distinct directories even when they share a branch. Keep records outside tracked files: never commit them, put
progress in an Agent Note, or replace Home Manager-managed files. Secrets stay in their credential store; record
evidence paths and access prerequisites, not credentials.

Name the absolute path in the thread, in every brief and in every handoff, so compaction summaries and other owners
keep it. Link it when someone needs resumption evidence; do not repeat its contents in every progress message.

## Rules for every shape

**Current state is rewritten in place.** Update it when a decision, revision, gate, review disposition, publication
or next action changes, and before a handoff or manual compaction. A history log is optional and is never read in
full by default.

**Decisions.** Record who decided what, why, and the source; the type (product, authority, scope, temporary
exception, technical); scope or expiry; and what it supersedes.

- Only a person makes a decision. An automated recommendation, a review bot's verdict or an answer a service
  recorded under someone's name is not a decision until that person confirms it. When it conflicts with a recorded
  decision, ask the user.
- Never rewrite a decision's statement. Record the change as a new decision and mark the old one superseded.
- Before proposing an investigation or new work, check whether a recorded decision already settles it.
- When a decision is superseded, find copies of the old one: briefs of running workers, tickets, repository docs and
  skills, the record itself. Update the copies you own, tell affected workers, and raise copies owned by others
  with the user.

**Questions for the user.** Record the question before asking it, with what it blocks, a context that answers it
without the transcript, the options and your recommendation.

- A question asked through a dialog that was cancelled or not confirmed as delivered stays open.
- While questions are open, end each message to the user with a short list of them: one line each and what it
  blocks. Do not repeat the full context each time.
- Record the answer verbatim with its date, record the resulting decision, and pass it to whoever asked.

**Resumption.** Read the current state, the active decisions and the open questions first. Then check live state
before acting on it: the actual checkout path, branch, dirty state and commits, including unpushed work; running
processes and builds; PR, MR and pipeline state; worker thread status. The record is a recovery aid, not authority
over newer user instructions or proof that live state stayed unchanged. Correct it where live state differs. Do
not rebuild state from provider transcripts unless the record lacks a fact; when it does, add the fact.

## Task record

One file with the fields from the [templates](references/templates.md#task-record) that the task needs. Preserve
the tested revision and explain any valid reuse of evidence across later commits. Do not restart an owner or
watcher merely because it waits. Keep the record and runnable evidence while review, handoffs or unresolved gates
need them.

## Ledger

Four files, started from the [templates](references/templates.md#ledger). The coordinator is their only writer.
Workers read `STATE.md` and `decisions.md` when their brief points to them, and report back. If the user edits a
file, re-read it before your next write and keep their change.

- **`STATE.md`:** current facts only, under about 150 lines: goal and scope, active authority by decision ID, one
  row per workstream (owner thread, task record, branch, MR, head SHA, status, blocked by, next action), blockers,
  next actions, and when and against what it was last reconciled. When a workstream is finished and nothing depends
  on it, replace its row with one line in `log.md`.
- **`decisions.md`:** one entry per decision with an ID (`D-001`) and status (`active`, `superseded`, `expired`).
  Briefs, tickets, documents and MR descriptions that rely on a decision cite its ID instead of restating it.
- **`inbox.md`:** one entry per question with an ID (`Q-001`), the asking thread and a status (`open`, `answered`,
  `withdrawn`). Name the ID in the question. The open-questions list at the end of each message includes the
  inbox path. When answered, mark the entry with its decision ID and send the answer to the asking thread.
- **`log.md`:** one dated line per launch, merge, reconciliation, supersession or closed workstream, with links.

Update the ledger after every user decision or answer; when a worker report, pipeline result or merge arrives
(compare reports with active decisions, and send a correction or ask when they conflict); and before launching a
worker, whose brief names the ledger path as read-only and cites the decision IDs it relies on.

The ledger is personal. A decision that teammates or other repositories rely on also belongs with its shared owner:
repository docs or an ADR, the ticket, or the project's decision record. Put that location in the decision entry
and keep both consistent; for the team, the shared copy wins. When the project ends, expire temporary exceptions,
make sure lasting decisions live with their shared owners, and mark the ledger closed. Ask the user before deleting
it.
