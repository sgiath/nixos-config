# Agent Note: plan-driven slice loop for multi-session features

Status: proposed

## Problem

Large features in core_v2 are delivered as a long series of agent sessions,
and the user currently runs that series by hand. For the **spider** app
(2026-08-17 to 2026-10-02) and the **support tickets** system (2026-09-22 to
2026-10-05) the user was the loop: they started each next unit, relayed CI and
review state, asked for commits and PRs, merged, deployed, told the next agent
what had been deployed, and carried lessons from one session to the next. The
agents did the implementation well. The cost sat in the loop around them.

Matt Pocock's `implement-spec` (skills v1.3) automates such a loop with a spec,
a ticket graph, parallel implementers, and one integration branch. Its shape
does not match how this work actually ran: merge and deploy happened between
slices, and decisions were made at slice boundaries. This note records what the
sessions show and proposes a system built from that.

### Sources

Short prefixes used below. Every reference is a session file stem; prefix it
with the directory shown.

| Prefix | Directory |
| --- | --- |
| `ce/` | `~/.omp/profiles/crazyegg/agent/sessions/-develop-crazyegg-core_v2/` |
| `df/` | `~/.omp/agent/sessions/-develop-crazyegg-core_v2/` |
| `fs/` | `~/.omp/agent/sessions/-develop-crazyegg-core_v2.feat-spider/` |
| `ao/` | `~/.omp/agent/sessions/-.ao-data-worktrees-core_v2-*/` (agent-orchestrator) |
| `jev/` | `~/.omp/profiles/crazyegg/agent/sessions/-develop-crazyegg-core_v2.feat-spider-jev-classification/` |
| `cc/` | `~/.claude/projects/-home-sgiath-develop-crazyegg-core-v2/` (T3 Code threads, Claude harness) |
| `cx/` | `~/.codex/sessions/2026/09/01/` (Codex arena run) |
| `oc:` | session id in `~/.local/share/opencode/opencode.db` (oh-my-opencode) |

The `remote` omp profile and pi had no sessions for either feature. Git and PR
data come from `CrazyEggInc/ce` (the core_v2 remote) and `CrazyEggInc/db-schemas`.

### Evidence: volume

| | Spider | Support |
| --- | --- | --- |
| Sessions | ~120: omp 91, omo ~20, Codex 7, Claude 2 | ~73: omp 64, Claude/T3 9 |
| ce PRs | 13 (10 merged, 3 open stack) | 52 (51 merged) + db-schemas companions #685–#719 |
| Direct pushes to master | 31 of 97 commits | 50 of 200 commits |
| Median PR | +2,287 lines, 1.3 h open | +695 lines, 0.5 h open (40 of 51 under 1 h) |
| Human reviewers besides the user | none | none |
| PRs without a CodeRabbit review (rate limit or skip) | 1 of 13 | 25 of 52 |

User input, classified message by message from the transcripts (typed
messages, plus slash-skill invocations and answers to agent `ask` prompts):

| Slice | Typed | Mechanics | Context-paste | Decision | Correction | Question | Skill invocations | `ask` answers |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Spider 08-17..09-16 (omp + omo + Codex) | ~201 | ~48 | ~28 | ~53 | ~25 | ~47 | 0 | few |
| Spider 09-17..10-02 | 90 | 39 | 8 | 20 | 10 | 13 | 5 | 2 |
| Support 09-22..09-24 | 48 | 13 | 5 | 16 | 5 | 9 | 10 | 18 |
| Support 09-25..10-03 | 125 | 59 | 4 | 44 | 7 | 11 | 5 | ~22 |
| Support 10-03..10-05 (T3) | 47 | 11 | 13 | 12 | 7 | 4 | 2 | 1 |
| **Total** | **~511** | **~170** | **~58** | **~145** | **~54** | **~84** | **22** | **~45** |

About a third of typed messages were loop mechanics ("submit PR", "commit it",
"Implement the next step", "resolve conflicts", "CI failed", "it is deployed").
Counting slash-skill invocations and messages that only carried text from one
session to another, the share is about 47%. Real decisions were about 27% of
typed messages, plus most of the ~45 `ask` answers. Wall-clock time cannot be
measured from transcripts. What can be measured is the latency: the next
support phase usually started seconds to two minutes after the user merged the
previous PR (#5298 merged 17:46:10, next prompt 17:46:22 in `ce/2026-10-02T17-46`;
#5288 12:52:54 → 12:53:39 in `ce/2026-10-02T12-53`). The user was watching the
loop.

### Evidence: how the user split and ran the work

**Spec layer is always an Agent Note, written by an agent after a discussion.**
The repeated pipeline was: question or investigation, then "write me that
proposal" / "Save all your investigation somewhere sensible in the repo"
(`ce/2026-09-22T15-04-05` 15:30), then often "set up a robust way to test it
locally with production data" (`ce/2026-09-18T06-59-02`, `ce/2026-09-19T10-01-06`),
then "Implement @<note>" (six times on spider: `ce/2026-09-17T11-43-33`,
`ce/2026-09-18T08-00-02`, `ce/2026-09-18T14-57-59`, `ce/2026-09-19T10-42-19`,
`ce/2026-09-19T15-03-40`, `ce/2026-09-23T07-48-07`). Spider used one note per
decision (21 implemented, 6 proposed in `spider/.agents/notes/`) and recorded no
ordering between them.

**Support turned one note into a phase ledger and a work queue.** In
`ce/2026-09-23T09-23-06` the user asked: "break it down to individually testable
and deployable phases" and "make it so when I ask next agent to implement 'next
step' it is clear what I mean by it, what is already done and where the model
should stop and possible questions that should be answered before the work on
that phase is started". The result
(`.agents/notes/proposed/architecture/2026-09-22-support-domain-gmail-ingestion.md`,
commit `095f111c02`) had an execution checkpoint, a seven-rule "agent execution
contract" (select exactly one phase, resolve pre-start questions, implement
only the deliverable, prove the acceptance gate, stop, separate implementation
from rollout), and for every phase: prerequisites, deliverable, acceptance
gate, questions before starting, and stop boundary. This is the user's own
design for a ticket. It has no dependency graph; order is the phase number plus
prerequisites. The note took 123 commits, grew to 2,242 lines with 64 handoff
records, was cut to 148 lines on 09-30 (#5251), and is back to 693. Phases were
renumbered at least three times (`ce/2026-09-23T18-51-19` 21:17 and 07:14,
`ce/2026-09-24T07-23-49` 07:41, `ce/2026-10-01T19-47` 20:17).

**The user was a literal for-loop.** Ten sessions opened with
`/skill:own-change Implement the next phase in @.agents/notes/proposed/architecture/2026-09-22-support-domain-gmail-ingestion.md`
(`ce/2026-09-23T09-59-55` through `ce/2026-09-25T06-09`), then twelve sessions
opened with the byte-identical "Implement the next step from @…" (for example
`ce/2026-10-01T20-34`, `ce/2026-10-02T09-05`, `ce/2026-10-02T12-36`,
`ce/2026-10-02T17-46`, `ce/2026-10-03T12-28`). The twelve loop sessions averaged
1.8 typed messages each, mostly mechanics. Their decisions went through `ask`.

**Merge and deploy were the user's gate between slices.** "I am merging and
deploying manually between the phases" (`ce/2026-09-23T13-50-28`, ask answer
13:52). The user told agents a phase was deployed at least five times
("Phase 2 is deployed in prod, mark it as such", "Also phase 5 is already
deployed", "It is now deployed, what should I do now?"). The convention
"merged means deployed" that followed was wrong at least once: "k8s-config
still pinned prod admin to `v1.0.433`, which doesn't contain the #5145 merge"
(`ce/2026-09-23T18-51-19`). Merge authority was handed over only once: "You have
my permission to merge it automatically. I will do the deploy after"
(`ce/2026-10-01T15-47` 17:11).

**Decisions happen at slice boundaries, not mid-slice.** The phase sessions put
retention, access, thresholds, folder rules and states to the user through
`ask` (18 answers in 09-22..09-24; ~22 in 09-25..10-03; e.g. `ce/2026-10-02T09-05`
Q2–Q11, `ce/2026-10-02T12-53` routing threshold "≥ 0.80"). In the T3 phase the
agent ended a proposal with numbered decisions and the user answered "1. yes /
2. no, these should go away too" (`cc/dba7a7a8` 18:22) or "1. agreed 2. Agreed
3. one address is fine" (`cc/35afbc1d` 08:58). Stale state caused one wrong
"next step": the agent re-asked phase-26 gate questions already answered on an
unmerged branch (`ce/2026-10-02T10-54`); the user restarted with the identical
prompt.

**Replanning came from evidence: production data, stakeholders, and using the
app.** Examples: the 24-phase reorder after analysing production mail
(`ce/2026-09-24T07-23-49`), the PM plan pasted in `ce/2026-09-24T16-18-16`, the
"brain dump" after a call with the Support lead that became
`2026-10-01-support-ticket-ui-rework.md` (`ce/2026-10-01T19-48`), and the Slack
DM that worked as a queue on 10-04 (`cc/dba7a7a8`: 12 of 20 prompts were Slack
links, 17 commits straight to master). Corrections came from screenshots of the
running app, not from diffs: "Why are we treating these pages with different
query params … as different pages?" (`ce/2026-09-18T08-00-02` 09:20), "I see
duplicates now..." (`ce/2026-09-19T15-03-40`), "the splitting/joining … should
not be the first thing when I open the ticket" (`ce/2026-09-24T15-39-02`).

**Two lanes ran side by side.** The planned lane (one phase PR at a time, in a
`wt` worktree) and an ad hoc lane (screenshot or Slack fixes, often on master in
the main checkout: "Implement it directly on master branch", `cc/dba7a7a8`
18:22; "do it on master directly", `cc/35afbc1d` 10:24). The ad hoc lane caused
repeated conflicts in the plan note (`ce/2026-09-27T17-19`, `ce/2026-09-29T10-57`,
`ce/2026-10-01T21-11`, `ce/2026-10-02T13-08`, `ce/2026-10-02T13-43`) and one
commit that swept up another session's files (`ce/2026-09-28T15-03`). Peak
concurrency was about three sessions for support and about five for spider
(08-20 audit fan-out, 08-26 implementer plus reviewer).

**Parallelism that worked was inside a session.** A lead agent wrote a shared
contract file (`local://observed-pages-contract.md`, `phaseNN-spec.md`) and fanned
out implementer, scout and reviewer subagents (4 in `ce/2026-09-17T11-43-33`, 5 in
`ce/2026-09-18T14-57-59`, waves in `ce/2026-09-23T07-48-07`). Parallelism across
sessions was manual: the same prompt sent to several sessions (`oc:ses_fea99c954ffe`,
`oc:ses_fea999f51ffe`, `oc:ses_fea3398b7ffe`), audit findings pasted into four
sessions within 26 minutes (`fs/2026-08-20T09-10-12` → `fs/2026-08-20T09-32-54`,
`09-48-10`, `09-48-39`, `09-59-18`), and reviewer findings relayed by hand
between an implementer and a `/review` session (`df/2026-08-26T11-48-38`,
`df/2026-08-26T12-48-43`).

**Fresh session per unit; the handoff is always a file or a PR.** No session in
the late spider or support slices hit compaction. Context was never pasted from
one transcript into another. It went through notes, PRs, Shortcut or Slack links.
When asked for "a prompt for the next agent" the user ignored the generated
40-line prompt and used their own one-liner (`ce/2026-10-01T09-48` 13:01). In
T3 the user forked a thread at a proposal message to answer its numbered
decisions without three unrelated fixes in between (`cc/c1b83b81` forked from
`cc/dba7a7a8` at 06:51).

**Merging.** Agents never merged without authority. Every PR was a GitHub merge
commit merged by the user. Spider started as one 40-commit branch landed as
#4902 (+31,389 lines, 228 files; CodeRabbit refused: "Too many files"), then
31 direct pushes, then one PR per slice. Twice the user merged while the agent
was still pushing ("I have already merged the PR, can you push it on master
branch instead", `ce/2026-09-19T10-42-19` 12:23). One stack exists (#5283 →
#5191, #5284, built in `ce/2026-10-02T09-10-04`).

### Evidence: what the agents did

**Good unattended.** Given a note or "next step", an agent created paired `wt`
worktrees in core_v2 and db-schemas, wrote the migration, fanned out
implementers, verified against production-like data in a browser, opened
cross-linked PRs with the `db:<branch>` label, handled CodeRabbit with evidence,
and updated the plan (`ce/2026-09-23T09-59-55`; `ce/2026-09-24T14-50-29` ran 48
minutes with no input). The agent-orchestrator PR worker handled 11 CodeRabbit
threads and found two CI root causes alone (`ao/…core_v2-3/2026-09-18T12-26-02`).
Agents proved new tests can fail by breaking the code on purpose, and they
usually stated what they had not verified.

**Recurring failures that no session fixed for the next one.**

| Failure | Occurrences |
| --- | --- |
| Credo pipeline rule vs Styler, found only in CI | ~8 sessions, 09-17..09-28 |
| Hand-stripping local `oban_count_estimate` from `schema.sql` | ~8 sessions, 09-27..10-02 |
| Forging an admin session to log in locally, after the user asked to document the login | 5 sessions (`ce/2026-09-24T11-47-22` 12:10 asked; `ce/2026-09-24T21-23-14` did it again) |
| Missing or stale `db:<branch>` label on the ce PR | 3 (#5104, #5135, `cc/35afbc1d` 09:41) |
| Edits leaking into the main checkout through relative paths | 4+ (`ce/2026-09-18T08-00-02`, `ce/2026-09-19T10-42-19`, `ce/2026-09-24T19-11-43`, `ce/2026-09-28T10-54-30`) |
| Subagents overwriting each other in a shared worktree | 2 (`ce/2026-09-18T08-00-02`, `ce/2026-09-23T07-48-07`) |
| Migration version races between parallel sessions | `ce/2026-10-02T13-43` 15:15 |
| `gh pr checks --watch` exiting before checks registered, or without timeout | `ce/2026-09-24T19-11-43`, `ce/2026-10-03T13-21` (~10 kills) |
| UI change shipped without a browser check, bug reported later by screenshot | most T3 threads (`cc/dba7a7a8` 06:52, `cc/35afbc1d` 09:24; follow-ups `cc/e3f3c0f8`, `cc/e65306cc`, `cc/c7de55d5`) |
| Reported done, failed in real use | DD_VERSION and launcher (`df/2026-08-25T18-11-06`), Atlas F3 "Runtime QA" box ticked but crawl resume broken (`oc:ses_fdaeb6e81ffe`) |
| Progress recorded inside a proposed note, caught by CodeRabbit | #5308, #5314 |
| An instruction from one thread lost in the next ("remove all the alerts", `cc/dba7a7a8` 18:10 → "Remove that alert", `cc/a6732241` 10:33) | 2 |

**Drift.** Agents leaned toward caution and rigidity that the user reversed:
DB CHECK constraints dropped twice (`ce/2026-09-29T10-57`, `ce/2026-10-03T13-21`),
a security review overruled ("They are the final arbiter", `ce/2026-10-02T15-55`),
"Design agreed by the user" written for a design the agent proposed (advisor
catch, `ce/2026-09-24T16-18-16`), an unbounded export of production mail bodies
stopped by the advisor (`ce/2026-09-24T19-11-43`), and a detour decrypting
Chromium cookies ("What are you doing? Can you just use the browser tool?",
`ce/2026-10-01T09-48`).

### Evidence: tools tried

- **own-change**: the main loop driver for support phases 1–10 (10 invocations).
  It was not used in the T3 phase, so the user typed "submit PRs" and pointed
  at CodeRabbit comments and CI by hand (`cc/c1b83b81` 07:57, `cc/35afbc1d` 09:41).
- **babysit-pr**: about 9 slash invocations, otherwise run inside own-change.
- **T3 `watch_pull_request`**: drove 30 PR-loop turns on 10-04/05 with no user
  input. It also duplicated context: wake-ups resumed from an older message and
  produced two interleaved branches in one session, which made the agent report
  "Another session seems to be fixing review findings on this branch"
  (`cc/28cf3727` 09:51, 10:06; `cc/ad93e2ee` 00:11).
- **agent-orchestrator** (`~/.ao`, 2026-09-18 12:03–13:26): abandoned after one
  afternoon. `claim-pr` rejected every PR reference, workers reported to a
  branch name instead of the session id, a brief arrived as literal
  `$(cat /tmp/…)`, 33 relayed messages against 4 human ones, and the discovery
  worker could not see the untracked note that held the spec
  (`ao/…orchestrator-core_v2-orchestrator/2026-09-18T12-10-32`). The user went
  back to a plain session at 14:58 (`ce/2026-09-18T14-57-59`).
- **oh-my-opencode Prometheus → Atlas** (spider, 08-20..08-24): plan with waves,
  a dependency matrix, TDD todos, and a commit per todo. It produced the
  31k-line branch and the false "Runtime QA" completion.
- **arena / architect**: one Codex run (`cx/`, 09-01), plus manual arenas
  (the same prompt to several sessions).
- **Not used for these features**: coordinator, herdr, tdd as a slash skill,
  plannotator.
- The `ask` tool and the advisor carried most of the value outside
  implementation: real decisions, and catches of real errors.

## Proposal

A **plan-driven slice loop**: a skill (working name `drive`) plus a small
deterministic status script. The user keeps every decision they made in these
sessions. The loop takes over everything the user typed as mechanics.

### Working style the system must fit

1. Specs come out of a conversation and are written as Agent Notes. Writing them
   stays interactive.
2. The unit of delivery is one PR-sized, independently deployable slice with an
   acceptance gate and a stop boundary, plus companion db-schemas PRs when a
   migration is needed. This is the support phase format, which the user
   designed.
3. Slices run mostly in sequence. The user merges, deploys, and looks at the
   result in the app or in production data before the next dependent slice
   starts.
4. Decisions are made at slice boundaries through structured questions, often
   in batches with numbered answers.
5. The plan changes often, driven by production data, stakeholders and using
   the app. Plan order is priority, and it can be rewritten at any time.
6. Ad hoc fixes from screenshots and Slack run beside the plan, often directly
   on master.
7. Inside a slice, the agent may fan out subagents around a contract file.
8. Review means CodeRabbit plus the user trying the app. Code review by a human
   other than the user does not happen.

### Artifacts: spec, plan, state

- **Spec**: Agent Notes, as today. Decisions and architecture only. No
  progress, no handoff records, no deploy status, which matches the existing
  rule that progress never goes into a proposed note.
- **Plan**: a directory committed in the repository,
  `.agents/plans/<yyyy-mm-dd>-<topic>/`:
  - `plan.md`: pointers to the spec notes, the goal, standing rules for this plan
    (verification with production data, merge authority, whether slices are
    deploy-gated, parallel limit), and the slice order.
  - `NN-<slug>.md`, one file per slice: `Blocked by`, `Deploy gate: yes|no`,
    `Migration: yes|no`, Deliverable, Acceptance gate, Questions before starting,
    Stop boundary. One file per slice avoids the write races and the
    2,242-line ledger. It is also what `implement-spec`'s local tracker
    settled on.
  - Slice files change in two places only. Planning sessions edit them on
    master. The slice's own PR adds the answers to its questions and moves
    decisions into the spec note. The driver never commits.
- **State is derived, not written.** `plan-status <plan-dir>` (deterministic,
  JSON output) computes each slice's state from:
  - the slice files,
  - `gh pr list` for the slice branch `<topic>/NN-<slug>` in ce and db-schemas,
  - the running worker thread,
  - a deploy check that asks whether the production image contains the merge
    commit.

  States are `blocked`, `ready`, `asking`, `running`, `in_review`, `merged`,
  `deployed`. This replaces the 62 `docs(support)` bookkeeping commits, the
  "record phase N deployed" ritual, and the "merged means deployed" shortcut.
- **Handoff record**: the slice PR body, written with the `pr` skill (Summary,
  Evidence, Merge Danger). It also lists anything not verified and the exact
  next action. The PR is the durable record. It is not copied into the note.
- **Traps file**: `~/.local/state/drive/<repo>/<plan>/traps.md`, kept outside the
  repository. Each worker's final report lists the friction it hit, and the
  driver appends it here. Every worker prompt points at the file. At the end of
  the plan, or every five slices, the driver proposes `/retro`-style permanent
  fixes: an AGENTS.md line, a check, or a skill edit. The user picks. This
  targets the table of recurring failures above.

### Roles

- **Planner** (interactive, run by the user): `/drive plan @<note>` turns a note into
  `plan.md` and slice files, asks the user to confirm the cut and the order,
  and commits on master. `/drive replan` folds new findings in, the way
  "fold your findings into the plan" did. Slices may be renumbered, but
  numbers stay stable as names.
- **Driver** (one long-lived thread per plan, holding no code): the loop below.
  It keeps no state of its own. Every wake-up starts from `plan-status`, so the
  driver can be restarted in a fresh thread with `/drive @<plan>` at any time.
- **Worker** (one thread per slice): launched in a new worktree from
  `origin/master` on branch `<topic>/NN-<slug>`. Its prompt is only pointers:
  "Implement slice @<plan>/NN-<slug>.md under @<plan>/plan.md. Answers to the
  slice questions: <answers>. Known traps: @<traps.md>". The worker runs
  `own-change`, which already owns the worktree, the companion db-schemas PR,
  the PR with evidence, and babysit-pr. It keeps its own subagent fan-out with
  absolute worktree paths and disjoint file ownership. It ends at merge-ready.
- **Reviewers**: CodeRabbit through babysit-pr, as now. Before the PR is opened,
  a local review pass (`code-review` or a reviewer subagent on a different model)
  runs, because CodeRabbit skipped 40% of these PRs. UI slices need a browser
  screenshot in Evidence, because missing browser checks were the most common
  cause of follow-up bug reports.

### The loop

On each wake-up (worker finished, PR watch event, deploy tick, user message):

1. Run `plan-status` and re-read `plan.md`. Never use cached plan state, so
   replans and ad hoc commits on master are always picked up.
2. Clean up: remove worktrees of merged slices with `wt remove`. Forty-three
   stale worktrees had piled up by 10-03.
3. If a slice is `in_review` and its worker stopped before merge-ready, send the
   worker back once with the unmet condition: CI red, an actionable thread, no
   Evidence, a UI change without a screenshot. Escalate to the user if it
   happens again.
4. If a slice is merge-ready, notify the user with one line and the PR URLs.
   The user merges. If `plan.md` grants merge authority, the driver merges with
   `gh pr merge --match-head-commit` and still leaves deploy to the user.
5. Frontier: `ready` slices whose blockers are `deployed`, or `merged` when the
   blocker has `Deploy gate: no`. Pick in plan order. The default parallel
   limit is one running slice. A second slice may start only if both have
   `Migration: no` and do not touch the same app.
6. **Ask ahead.** As soon as a slice becomes the next candidate, while the
   previous one is still in review or waiting for deploy, run a short read-only
   research task. It grounds that slice's questions in current code and
   production data. Then put all of them to the user in one batch with
   recommended answers. This moves the gate questions off the critical path:
   they are answered while CI runs, not after the merge.
7. Launch the worker once its questions are answered. Post one status line in
   the driver thread.
8. Stop when every slice is `deployed`. The final slice's PR moves the spec
   notes to `implemented/` and deletes the plan directory. Also stop when the
   driver is blocked on the user, or when a slice has failed twice.

### Host

T3 Code is the recommended host for the driver and the workers:

- `t3_thread_launch` takes a worktree `workspaceStrategy`.
- `watch_pull_request` already ran the PR loop without the user.
- Thread completion wakes the parent.
- Workers are user-visible threads, which matches how the user steers and
  answers `ask` prompts.

`schedule_task` gives the deploy tick, at 10–15 minutes, only while a merged
slice is waiting for deploy. The design does not depend on T3 beyond that.
`plan-status`, the slice files, and the worker prompt work the same way from
herdr with omp (`herdr-thread` launches a worker and herdr reports agent state).
That choice is open; see
[decide T3 Code's fate after the herdr web UI trial](../simplification/2026-10-02-t3code-after-herdr-web-trial.md).

### Where the user steps in

| Step | User | Automated |
| --- | --- | --- |
| Question → proposal note | yes | — |
| Cutting the plan into slices, order, replans | approves | planner drafts |
| Slice gate questions | answers one batch per slice | researched and asked ahead |
| Implementation, tests, worktrees, PRs, CI, CodeRabbit, conflicts | — | worker (own-change, babysit-pr) |
| Merge | only for services outside `autonomy: deploy` | driver, for listed internal services |
| Deploy and production check | only for services outside `autonomy: deploy`, `manual` migrations, failures | driver through the local release CLI; verified, never assumed |
| Product review in the app | yes, by screenshots into a replan or a side request | — |
| Ad hoc fixes from Slack or screenshots | starts them as today, outside the plan | — |
| Permanent fixes for recurring traps | picks | proposed from the traps file |

What the loop removes, going by counts from the sessions: about 22 loop-start
prompts, ~30 "commit / submit PR" messages, ~20 relays of CI or review state,
~8 conflict requests, 5+ "it is deployed" messages, "already merged, push to
master" confusion, and worktree cleanup.

### Automatic merge, deploy and migrations

For internal, non-customer-facing services listed in `plan.md` (for example
`autonomy: deploy` for `admin_web`, `spider`), merging, deploying and checking
production become part of the loop. The setting is the durable authorization;
services outside the list fall back to the user.

The existing release machinery already covers most of the safety:

- Spider and the release dashboard are CI-deployed on every master push
  (`release_dashboard/lib/release_dashboard/deployments/ci_deployed_services.ex`).
- Release targets such as `admin_web` deploy through a deploy request. The
  dashboard verifies the revision live and healthy in Argo, and runs a revert
  deploy on an explicit rollout failure.
- A Migration Run (`release_dashboard/CONTEXT.md`) runs staging first and moves
  to production only after every database verifies. It holds a migration lock,
  runs a read-only preflight, and requires the stored version to read back with
  `dirty = false`. Migrations never roll back automatically.

Two pieces are missing. The dashboard has only browser routes, so nothing can
drive it from a script. And nothing decides which migrations are safe to run
unattended. The plan fills both:

- **A local release CLI in core_v2.** It performs the dashboard's operations
  (deploy request and verification, revert, CI-deployed rollback, Migration
  Run) from a developer machine. It uses the already-authenticated `aws`,
  `kubectl` and `git` instead of calling the dashboard, and it respects the same
  locks.
- **A migration classifier in db-schemas CI.** It labels every migration PR
  `migration:auto` or `migration:manual`. A migration is `auto` only if all of
  the following hold:
  - every statement is additive: `CREATE TABLE`, an index on a table created
    in the same migration, a nullable or constant-default `ADD COLUMN`, or a
    foreign key from a new table;
  - every object it touches is owned by the feature (a declared prefix such as
    `metadata.support_*`) or created in the same migration;
  - it has no DML, and no `-- migrator:allow` lint escapes (an agent used one to
    get #719 through lint);
  - its `down` drops only what `up` created;
  - only new files are added; an applied migration is never edited (the
    support migrations were squashed and changed during development:
    `0a85559`, `8ec344b`).

  MySQL `core`, ClickHouse `events`, and anything touching shared tables are
  always `manual`.

For a slice with an `auto` migration, the driver works in this order:

1. Merge the db-schemas PR.
2. Run the staging → production Migration Run and wait for a verified migration
   in both environments.
3. Merge the ce PR.
4. Deploy: CI does it for spider; for release targets, create a deploy request
   and wait for a verified deploy.
5. Check production: error rates for N minutes, read-only production queries
   for the acceptance gate, and a browser check for UI slices.
6. Mark the slice deployed.

"Successful but unverified" stops the loop, the same as a failure.

When something fails, the driver reverts the code and stops. It never runs a
migration `down`; an additive migration left in place is harmless to the old
code. A dirty database, an interrupted run, a `manual` migration, ClickHouse
migrations, and recovery runs always go back to the user. New behavior ships
switched off where possible, and the production check turns it on.

The classifier's evidence would be stronger with two more db-schemas CI jobs: an
up/down/up run on a fresh database, and a rehearsal on a production-shaped dump
with the migrator's lock timeout.

### Spider-style work

Work that is one note and one PR stays a plain `/own-change Implement @<note>`.
The driver adds value only once there are two or more ordered slices. A
spider-style design with many small notes can still be driven by a plan whose
slices point at different notes.

## Alternatives considered

- **Matt Pocock's `implement-spec`.** It runs parallel implementers for a ticket
  graph, merges each into one integration branch, then runs one `code-review`,
  then one PR. What fits:
  - a frontier computed from `Blocked by`,
  - one file per ticket,
  - context pointers instead of copied context,
  - exploration notes shared with later workers.

  All four are kept above. What does not fit:
  - (1) The integration branch delays merge and deploy to the end. The user's
    verification of each slice was its production deploy and production data,
    and later slices depended on what that showed. The phases were reordered
    several times because of it.
  - (2) One large PR is the #4902 shape: +31k lines, no review, CodeRabbit
    refused it.
  - (3) Migrations need ordered companion db-schemas PRs for each slice, and
    parallel migrations raced.
  - (4) Its `tdd` step expects seams confirmed with the user, which background
    implementers cannot do. Its own notes also admit three gaps: no merger
    contract, no status tracking during a run, and no stop condition after the
    review fix.
  - (5) It has no place for gate questions or for merge and deploy authority.
- **A deterministic script loop**, e.g. a shell loop that sends "Implement the
  next step from @note" after each merge. It is cheap and the prompts really
  were identical. But almost every iteration needed judgment the script cannot
  provide: gate questions (~40 `ask` answers in phase sessions), replans,
  deciding whether a merge is deployed, conflicts, and sending a worker back for
  missing evidence. Instead, the deterministic parts move into `plan-status` and
  the deploy check, and an agent handles the judgment.
- **agent-orchestrator.** Tried on 2026-09-18 and abandoned the same afternoon
  for the reasons listed in the evidence. Its value was the babysitting worker,
  which own-change and babysit-pr already provide.
- **coordinator skill (workmux).** It merges agents' work itself and uses
  workmux worktrees. That contradicts own-change and babysit-pr, which never
  merge, and the rule to use Worktrunk.
- **Extending the support ledger note.** It already works as a protocol, but it
  breaks the user's rule against progress inside proposed notes. It grew to
  2,242 lines, conflicted with the ad hoc lane, and needed a docs commit for
  every state change.
- **More parallelism, several slices at once by default.** The sessions show
  little demand. The work was sequential because of deploy gating and
  migrations, and the parallelism that worked was inside one slice. The limit
  stays configurable per plan.

## Acceptance criteria

The skill is accepted after one real plan of at least five slices, for example
the remaining support capabilities or the open spider sc-83572 stack:

- The user types no loop-mechanics messages in worker threads. Interaction is
  limited to plan approval, one batch of gate answers per slice, merges, and
  product feedback.
- Every slice PR body has Evidence from checks that actually ran. UI slices
  include a screenshot.
- The driver makes no commits. Spec notes contain no progress records. Slice
  state is reproducible from `plan-status` alone.
- A slice is never reported deployed unless the production image contains its
  merge commit.
- Gate questions for slice N+1 are asked before slice N is merged.
- Merged slices leave no worktrees behind.
- Killing the driver thread and starting `/drive @<plan>` in a fresh one
  continues from the correct slice.
- At least one recurring trap is turned into a permanent fix: a check,
  AGENTS.md line, or skill edit that the user picked.

## Risks

- **T3 wake-ups fork worker conversations** (`cc/28cf3727`). Workers then
  mistake their own pushes for another session's. The loop relies on PR-watch
  wake-ups, so this needs to be fixed upstream or worked around by keeping
  watches on the driver rather than the worker.
- **Driver thread grows over days.** Mitigated by statelessness: re-derive
  everything each wake-up and restart freely.
- **Ad hoc commits on master change what a pending slice assumes.** The driver
  re-reads the plan on every wake-up, but it cannot detect semantic conflicts. The
  user still has to say "replan" after a side change that matters.
- **Parallel slices race** on migrations, the shared dev database, and ports.
  Hence the default limit of one, and `Migration: no` for any second slice.
- **Deploy detection depends on infrastructure** (k8s-config image tags,
  release dashboard). If it is unreliable, the fallback is the user telling the
  driver, which is today's cost.
- **Steering gaps.** Workers under Claude Code lack skills that exist only in
  omp managed skills (`parallel-pr-worktrees-elixir`,
  `crazyegg-pr-review-thread-triage`, `gh-actions-failure-diagnosis`). The
  evidence-based PR template on `chore/pr-template-evidence` is unmerged.
- **Autonomy creep.** Merge and deploy authority is per plan and per service,
  and limited to internal services. Customer-facing services and `manual`
  migrations stay with the user.
- **The local CLI bypasses the dashboard's in-process deploy lock.** It must
  honor an equivalent lock, or the CLI and the dashboard can race on one
  service.

## Open questions

1. **Plan location**: `.agents/plans/<topic>/` (recommended), a directory next
   to the spec note, or outside the repository?
2. **Host**: T3 Code threads (recommended) or herdr with omp? This interacts
   with the pending T3 Code decision.
3. **Workers as top-level threads or child tasks**: top-level `t3_thread_launch`
   threads (recommended, so you can steer and answer `ask` in them) or
   `delegate_task` children of the driver?
4. **Where gate questions are answered**: in the driver thread, asked ahead
   (recommended), or inside each worker thread as today?
5. **Default parallel limit**: one, with a second allowed only for
   migration-free slices in different apps?
6. **Autonomy scope**: which services may be listed under `autonomy: deploy`
   (proposed: internal ones only, such as `admin_web`, `spider`,
   `release_dashboard`)?
7. **Deploy detection**: is the k8s-config image tag the right source of truth
   for ce apps, or the release dashboard? Should non-deploy-gated slices be
   allowed at all?
8. **Worker harness and models**: Claude Code through T3 for everything, or omp
   workers? The managed CrazyEgg skills live only in omp. Keep your rule of
   Opus for implementation and gpt-6.1-sol for investigation subagents?
9. **Ad hoc lane**: keep Slack and screenshot fixes fully outside the driver, or
   let the driver accept them as single-slice side entries so they stop
   conflicting with plan files?
10. **Local review pass before the PR**: worth the extra cost and latency given
    CodeRabbit, and which skill or model should run it?
11. **Traps**: is an out-of-repo traps file plus a retro proposal every five
    slices acceptable, or should traps go straight into the repository
    AGENTS.md through the slice PR?
12. **Point-in-time recovery**: does the metadata Postgres have it? It decides
    whether any `manual` migration class could later become automatic.
13. **Feature-owned data**: is losing a feature's own tables acceptable if an
    `auto` migration later has to be dropped by hand?
14. **Naming and scope**: is `drive` the name, and should `plan`/`replan` be
    modes of it or a separate skill?
