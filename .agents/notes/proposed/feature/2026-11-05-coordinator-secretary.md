# Agent Note: Route worker and pipeline events through a secretary instead of the coordinator thread

Status: proposed

## Problem

In the Spain G2N sprint (2026-10-28 to 2026-11-05) one coordinator thread carried two kinds of traffic: the user's
conversation, and machine events from workers, pipelines, merges and tickets. The coordinator launched 148
top-level worker threads, many of which reported back into the same transcript
([thread inventory](/home/sgiath/.agents/local/spain-g2n-retro/12-child-and-sibling-threads.md)). The effects:

- Questions to the user were lost among worker reports. Two question dialogs aborted without confirmed delivery
  ([part A, around p470](/home/sgiath/.agents/local/spain-g2n-retro/10-mega-thread-part-a.md)), the coordinator had
  to remind the user of unanswered questions by hand, and the user had to search the transcript or ask for an
  explanation again.
- Waiting and wakeups were the largest measured token overhead: 1.221B units, $338.58 of exposure, not proven waste
  ([quantitative waste](/home/sgiath/.agents/local/spain-g2n-retro/20-traces-tokens-tool-failures.md#4-waste-and-avoidable-overhead)).
- The user asked for MR and ticket inventories on Nov 2, Nov 3, twice on Nov 4 and on Nov 5, each finding stale
  states ([part B](/home/sgiath/.agents/local/spain-g2n-retro/11-mega-thread-part-b.md)).
- A paired Neo/Tiger merge was not watched and blocked a teammate's recording for about an hour.

The [work-state](/home/sgiath/develop/crazyegg/home/.agents/skills/work-state/SKILL.md) ledger moves state,
decisions and pending questions into files that survive compaction. It does not stop machine events from arriving in
the coordinator's transcript. [Work-state hooks](2026-11-08-work-state-hooks.md) propose file-only checks
(re-adding the ledger after compaction, enforcing the open-question list) and leave event intake and live status
to this note.

## Proposal

Add a secretary beside the coordinator, in three phases. Measure each phase before starting the next.

**Phase 1: deterministic status, no model.** A script reads the ledger's workstream rows (branches, MRs, worker
threads, tickets) and writes `status.generated.md` next to `STATE.md` with the live state: MR head, pipeline
result and failed jobs, merge state, ticket state, worker thread state. It runs on a schedule and on demand. The
coordinator reads it instead of polling, and the user reads it instead of asking for an inventory. It writes only
that file, so it never conflicts with the coordinator's writes.

**Phase 2: event intake and classification.** Workers, the status script and review automation append events to
`events.jsonl` in the ledger directory: time, source, kind, reference, one-line summary, link. Append-only, any
writer. Each event is classified:

- `fyi`: changes state only (pipeline still running, a merge with no dependants). Nobody is woken.
- `actionable`: the coordinator must act (a dependency merged so the next work can start, a worker finished, a
  pipeline failed on a ready MR, a paired merge is half done). Wake the coordinator with a one-line pointer to the
  event.
- `needs-user`: a decision or approval only the user can give. The secretary drafts an inbox entry; the coordinator
  confirms it before it reaches the user.

Rules decide most classes. Reading a worker's free-text report needs a model; use a cheap one, invoked per event,
not a polling thread. An event that matches no rule is `actionable`, so an unknown event can cost a wakeup but
cannot be missed.

**Phase 3: a T3 inbox.** One view across threads of everything waiting for the user: agent questions from
`inbox.md`, pending approvals and dialogs (T3 already counts `pendingRequestCount` per thread). Each item keeps its
context snapshot and survives an aborted dialog. Answering routes the answer to the asking thread and records it.
Build this only after the file format from phases 1 and 2 has held up on a real project, so the T3 data model
follows a settled format.

## Alternatives considered

- **Keep everything in the coordinator thread (the Spain setup).** Simple, but it caused the lost questions and the
  wakeup overhead above.
- **A secretary as a long-running model thread that polls.** Polling is the overhead being removed, and most status
  is deterministic. Use a model only to read reports.
- **Build the inbox in T3 first.** The format is not settled; changing a T3 feature costs more than changing files.
- **Use the `drive` skill.** Drive has asked/answers state and a status script, but it needs a plan of slices
  agreed upfront. Spain's scope changed daily (21 issues read at the start, 113 by Nov 1), so an ad hoc
  coordinator is still needed. Phase 1 should reuse Drive's `plan-status` code where it fits.

## Acceptance criteria

- work-state's `question-survival` eval passes, extended to ten worker events between the question and the
  next user message.
- On a replayed sprint fixture, the coordinator is woken only for `actionable` events, and no `actionable` or
  `needs-user` event is missed, the half-done paired merge included.
- On the same fixture, coordinator wakeups and tokens drop compared with the Spain baseline. Report the numbers; do
  not promise a fraction in advance.
- `status.generated.md` matches live GitLab and ticket state for every row in the fixture.
- Phase 3: an aborted dialog's question remains in the inbox with its context, and an answer reaches the asking
  thread.

## Risks

- Two state files (`STATE.md`, `status.generated.md`) can disagree. The generated file is authoritative for live
  host state, `STATE.md` for intent and decisions; the coordinator reconciles them when they differ.
- A wrong classification hides an event. Defaulting unknown events to `actionable` limits this; the replay fixture
  checks it.
- The status script needs GitLab and ticket access. Use the existing CLI authentication; never write tokens into
  the ledger.
- Phase 3 depends on T3 internals that may change upstream.
- Open question for the user: should the secretary write inbox entries directly, or only draft them for the
  coordinator to confirm (the proposal above)?
