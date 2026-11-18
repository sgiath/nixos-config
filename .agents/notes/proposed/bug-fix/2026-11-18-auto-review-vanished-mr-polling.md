# Agent Note: Auto-review stops polling an MR that no longer exists

Status: proposed

## Problem

`packages/auto-review` keeps two persistent per-MR poll lists: MRs with an `open` or `disputed` tracked thread
(`threads`, read by `Threads._scan`) and MRs whose approval or reviewed state waits for a draft, pipeline, pause,
quiet hours or a failed write (`deferred`, read by `Threads.reconsider`). Both start each poll with `forge.change()`.

When the MR or its project is deleted, or the forge login loses access to it, `forge.change()` raises `ForgeError`
on every poll. `Engine._guard` records a `warn` event and sets `last_poll_error` each time (every 60 s by default),
and nothing ever removes the MR from either list. Restarts do not help: both lists are in SQLite. Before
2026-11-18 the deferred list was in memory and a restart cleared it; it was persisted then so that a restart no
longer forgets an approval waiting for a pipeline. Sol's review on 2026-11-18 reproduced the loop for a deferred
approval across three fresh `Store`/`Engine` instances.

A closed or merged MR that can still be read already ends both (closed threads; undeferred). A repo removed from the
settings stops both, but leaves its watched threads `open` or `disputed` in the table.

## Proposal

Stop on a permanent disappearance, keep retrying a transient failure:

- A `ForgeError` subclass, `ChangeGone`, raised by `GitLab.change` and `GitHub.change` only for a definite answer that
  the MR does not exist. A bare 404 is not one: GitHub and GitLab both answer 404 for a private resource the login
  cannot see ([GitHub](https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api#404-not-found-for-an-existing-resource)).
  It needs a second signal, for example the project still readable but the MR number missing from it. Network, auth
  (401/403), 5xx and ambiguous 404 failures stay plain `ForgeError`.
- On `ChangeGone`, `_scan` closes the MR's watched threads as `closed` and `reconsider` undefers it, each with one
  `warn` event naming the MR.
- Other `ForgeError`s keep retrying, but record the event only when the error text changes, so a long outage leaves
  one event instead of one per poll.

## Alternatives considered

- Give up after a fixed time (for example 7 days of failures). Simple, but an outage or lost token longer than that
  silently drops pending approvals and watched threads.
- Undefer on any `ForgeError`. Loses an approval on a transient failure, which the persisted list exists to prevent.

## Acceptance criteria

- A forge read that confirms the MR is gone undefers a deferred MR with one event, and closes an MR's watched threads
  with one event.
- An ambiguous 404 (the MR or project not visible to the login) leaves both the deferral and the tracked threads
  intact.
- A transient `ForgeError` keeps both lists and records one event per distinct error, not one per poll.
- Tests use the forge fakes for both cases; the forge classification is tested at the `run` boundary with the real
  `gh`/`glab` error texts.

## Risks

- `gh` and `glab` error texts are not a stable API; a changed text turns "gone" back into a transient retry, which is
  the safe direction.
- Access lost to a still-existing MR must not classify as gone, or a revoked membership would close its threads and
  drop its approval.
