# Agent Note: Auto-review redoes a stale judgment without waiting for a new reply

Status: proposed

## Problem

`packages/auto-review` skips a thread judgment when the thread changed after the review read it (`Threads.apply`:
other notes or a different tracked status). The skip bumps the thread's `skips` and records "the thread changed since
the review read it; judging it again later", but the redo is not guaranteed.

`Threads._scan` queues a follow-up per thread only when the digest of the notes by people other than sgiath is
nonempty and differs from `seen` (a new or edited reply); only then does the `skips` count enter the trigger key. A
follow-up queued for a new head (`trigger = "head"`) whose judgment is skipped because sgiath added his own note in
the thread while it ran cannot be redone: that digest still equals `seen`, and the `head` trigger of that head already
has a review row (the reviews UNIQUE key). The thread stays `open` and unjudged until the next such reply or the next
head, while the event says it will be judged again. Reproduced by Sol's review on 2026-11-18: a head-only follow-up,
then a note by sgiath, leaves one completed follow-up, an open thread and `skips=1`. The README "Acting" paragraph
describes this limit since the same date.

Simply clearing `seen` on a skip is wrong: a skip caused by sgiath's own decision (reply or keep open on a disputed
thread; an accepted thread is no longer watched and never reaches the skip) must stand, and a cleared `seen` would
queue a follow-up that judges it again.

## Proposal

Persist the skip itself as "still to judge", separate from `seen`:

- `apply()` records on a stale skip whether the cause was a changed note (`version` differs) or a changed status
  (sgiath's decision). Only the note case marks the thread as still to judge (for example a `rejudge` column holding
  the notes digest that was skipped).
- `_scan()` also queues a follow-up for a thread marked still to judge, with the marked digest in the trigger, so
  the same skip never queues twice.
- An applied judgment clears the mark.
- The skip event says what will happen: "judging it again in a follow-up" or "your decision stands".

## Alternatives considered

- Include `skips` in the `head` trigger. It queues a second head follow-up, but also after a status skip, which
  overrides sgiath's decision.
- Leave it and fix the event text and README only. Honest, but the thread still waits for an unrelated event.

## Acceptance criteria

- A head-triggered follow-up whose judgment is skipped because a note changed queues exactly one new follow-up on
  the next poll, without a new reply by another person.
- A skip caused by sgiath's reply or keep-open queues nothing.
- The skip event and the README "Acting" paragraph describe both cases.
- Existing thread tests in `packages/auto-review/tests/test_thread_safety.py` and `test_follow_up.py` pass.

## Risks

- A schema change to `threads`; old rows default to "nothing to rejudge".
- A loop if the redo is skipped again for the same cause; the mark keyed by notes digest bounds it to one follow-up
  per change of notes.
