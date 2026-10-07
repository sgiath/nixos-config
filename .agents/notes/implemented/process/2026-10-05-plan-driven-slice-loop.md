# Agent Note: plan-driven slice loop for multi-session features

Status: implemented

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
sessions show and the system built from that.

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

## Decision

The `drive` skill
([`modules/home/agents/skills/drive/`](../../../../modules/home/agents/skills/drive/SKILL.md))
runs a plan of slices. The user keeps every decision they made in these
sessions: writing the spec, cutting and reordering the plan, answering gate
questions, merging, deploying, and judging the result in the app. The skill
handles the mechanics: starting the next slice, PRs, CI and review loops,
cleanup, and asking questions at the right time. Automatic merge and deploy are
a separate proposal:
[automatic merge, deploy and migrations for drive plans](../../proposed/process/2026-10-05-automatic-merge-deploy-and-migrations.md).

### Working style it fits

1. Specs come out of a conversation and are written as Agent Notes. Writing them
   stays interactive.
2. The unit of delivery is one PR-sized, independently deployable slice with an
   acceptance gate and a stop boundary, plus companion PRs such as a db-schemas
   migration. This is the support phase format, which the user designed.
3. Slices run mostly in sequence. The user merges, deploys, and looks at the
   result before the next dependent slice starts.
4. Decisions are made at slice boundaries, in batches with numbered answers.
5. The plan changes often. Order is priority and can be rewritten at any time.
6. Ad hoc fixes from screenshots and Slack run beside the plan.
7. Inside a slice, the agent may fan out subagents around a contract file.
8. Review means CodeRabbit plus the user trying the app.

### Artifacts

- **Spec**: Agent Notes, as before. Decisions and architecture only, never
  progress.
- **Plan**: `.agents/plans/<yyyy-mm-dd>-<topic>/` in the target repository,
  committed and pushed to the default branch so workers branching from the
  remote can read it. `plan.md` holds the topic, repositories, parallel limit,
  delivery order, optional deploy check, goal, spec links and standing rules.
  Each slice is its own `NN-<slug>.md` with `blocked_by`, `deploy_gate`,
  `migration`, Deliverable, Acceptance gate, Questions before starting, and
  Stop boundary
  ([plan format](../../../../modules/home/agents/skills/drive/references/plan-format.md)).
  One file per slice avoids the write races and the 2,242-line ledger. Numbers
  are stable names; the `order` list is the delivery order.
- **State is derived, never written to the repository.**
  [`scripts/plan-status`](../../../../modules/home/agents/skills/drive/scripts/plan-status)
  prints JSON for every slice. It uses the slice files, `gh pr list` for branch
  `<branch_prefix><NN>-<slug>` in every listed repository, local branches, the
  optional `deploy_check` command, and marker files. Slice states are `blocked`,
  `ready`, `in_progress` (local branch, no PR), `in_review`, `closed` (PRs
  closed unmerged), `merged` (waiting for deploy), and `done`. It also prints
  the slices to launch (`next`, respecting the parallel limit and serializing
  migrations), the slice whose questions to ask ahead (`ask_next`), and
  `complete`. This replaces the bookkeeping commits, the "record phase N
  deployed" ritual, and "merged means deployed".
- **State directory** outside the repository,
  `${XDG_STATE_HOME:-~/.local/state}/drive/<repo>/<plan-dir>/`:
  - `answers/NN.md`: the user's gate answers;
  - `deployed/NN`: a deploy the user reported and `deploy_check` cannot see;
  - `traps.md`: friction that workers append.
- **Handoff record**: the slice PR body, written by `own-change` with the `pr`
  skill. The slice's own PR also records its answers in the slice file and
  moves resulting decisions into the spec note.

### Roles and loop

- **`/drive plan @<note>`** cuts the notes into slices, shows them as one table
  with the open questions, and commits and pushes the plan after the user
  approves. The last slice moves the spec notes to `implemented/` and deletes
  the plan directory.
- **`/drive replan`** folds in findings, adds slices with new numbers, deletes
  dropped ones, and invalidates answers whose questions changed.
- **`/drive @<plan-dir>`** makes the current T3 thread the driver. The driver
  holds no state. Every wake-up starts from `plan-status`, so a fresh thread
  continues correctly. Wake-ups come from a `schedule_task` tick every 15
  minutes bound to the driver thread, and from the user's messages. On each tick
  the driver does the following:
  - relays a stopped worker's question, or sends a stalled worker back once;
  - tells the user once that a slice is merge-ready (checks green, threads
    dispositioned, Evidence, screenshots for UI), with PR URLs, merge order and
    any migration to run;
  - removes merged slices' worktrees with `wt remove`;
  - waits for the deploy check or the user's deploy report;
  - asks the next slice's questions ahead, grounded by a read-only research
    subagent and with recommended answers;
  - launches answered slices;
  - turns repeated traps into `retro`-style proposals;
  - deletes the schedule when the plan is complete or only waits for answers.
- **Workers** are top-level T3 threads titled `<topic> NN: <title>`, launched
  in the project root. Each runs `/own-change` with a pointer-only prompt
  ([worker prompt](../../../../modules/home/agents/skills/drive/references/worker-prompt.md)).
  `own-change` creates the Worktrunk worktree on the slice branch, implements,
  publishes PRs, and babysits them to merge-ready. The prompt adds:
  - a read-only review pass before PRs, because CodeRabbit skipped 40% of these
    PRs;
  - screenshots for UI changes;
  - absolute paths for subagents;
  - stop and ask instead of guessing;
  - append traps to `traps.md`.

The user merges and deploys every slice. Invoking `drive` authorizes worker
threads, plan commits after approval, state files, and the driver's schedule.
It does not authorize merge, deploy, or migrations.

### Defaults chosen for the open questions

| Question | Choice |
| --- | --- |
| Plan location | `.agents/plans/` in the target repository |
| Host | T3 Code threads |
| Workers | top-level threads, so the user can steer them and answer `ask` there |
| Gate questions | in the driver thread, asked ahead |
| Parallel limit | 1 by default; a migration slice never runs beside another slice |
| Merge and deploy | the user, always (automation is proposed separately) |
| Deploy detection | `deploy_check` command per plan, else the user reports it |
| Ad hoc lane | outside the driver; the user says `/drive replan` when it matters |
| Traps | out-of-repo file, proposals after a repeat or every five slices |
| Name | `drive`, with `plan` and `replan` as modes |

Work that is one note and one PR stays a plain `/own-change Implement @<note>`.

## Alternatives considered

- **Matt Pocock's `implement-spec`.** It runs parallel implementers for a ticket
  graph, merges each into one integration branch, then runs one `code-review`,
  then one PR. Kept from it: a frontier computed from `blocked_by`, one file per
  ticket, context pointers instead of copied context, and a research step before
  workers. Not kept:
  - The integration branch delays merge and deploy to the end. The user's
    verification of each slice was its production deploy and production data,
    and later slices depended on what that showed.
  - One large PR is the #4902 shape: +31k lines, no review, and CodeRabbit
    refused it.
  - Migrations need ordered companion db-schemas PRs per slice, and parallel
    migrations raced.
  - Background `tdd` cannot confirm seams with the user. `implement-spec`'s own
    notes admit no merger contract, no status tracking during a run, and no stop
    condition after the review fix.
  - It has no place for gate questions or for merge and deploy authority.
- **A deterministic script loop** sending "Implement the next step" after each
  merge. Almost every iteration needed judgment the script cannot provide: gate
  questions (~40 `ask` answers in phase sessions), replans, deploy status,
  conflicts, and sending workers back for missing evidence. The deterministic
  part became `plan-status`; an agent handles the judgment.
- **agent-orchestrator.** Tried on 2026-09-18 and abandoned the same afternoon
  for the reasons in the evidence. Its useful part, the babysitting worker, is
  what `own-change` and `babysit-pr` already provide.
- **coordinator skill (workmux).** It merges agents' work itself and uses
  workmux worktrees, contrary to `own-change`, `babysit-pr`, and the Worktrunk
  rule.
- **Extending the support ledger note.** It breaks the rule against progress
  inside proposed notes. It grew to 2,242 lines, conflicted with the ad hoc
  lane, and needed a docs commit for every state change.
- **Waking the driver on worker completion or PR events.** Completion of a
  top-level thread does not notify the thread that launched it, and PR watches
  would duplicate `babysit-pr` in the worker. A 15-minute tick is simpler and
  enough, because the user's merge and deploy dominate slice latency.
- **herdr with omp as host.** It works the same way, through `herdr-thread` and
  agent states, but has no PR watch or scheduler. See
  [decide T3 Code's fate after the herdr web UI trial](../../rejected/simplification/2026-10-02-t3code-after-herdr-web-trial.md).

## Consequences

- The skill depends on T3 Code tools, and it stops without them. If T3 Code is
  removed, the driver steps need a herdr equivalent.
- Workers are invoked with `/own-change`, which is Claude Code and T3 syntax. omp
  workers would need `/skill:own-change`.
- `plan-status` parses only flat frontmatter. It finds PRs through GitHub
  search on the branch prefix, limited to 200 PRs per repository.
- A tick re-sends the driver conversation every 15 minutes while slices are
  active. The schedule is deleted while the plan only waits for answers.
- Answers live outside the repository until the slice's PR records them. Losing
  the state directory means re-asking the questions; nothing else is lost.
- Worker threads still have every failure listed in the evidence. The traps file
  only makes repeats visible; fixing them needs the user to accept proposals.
- Steering gaps remain. Workers under Claude Code lack skills that exist only in
  omp managed skills: `parallel-pr-worktrees-elixir`,
  `crazyegg-pr-review-thread-triage`, and `gh-actions-failure-diagnosis`.
- T3 wake-ups can fork a worker's conversation (`cc/28cf3727`), and the worker
  may then mistake its own pushes for another session's.
- Verification so far: `plan-status` was exercised against a scratch repository
  with a fake `gh` covering every state, `ask_next`, `deploy_check`, and answer
  markers. The loop has not yet driven a real plan. Its first real plan is the
  check that interaction falls to plan approval, one answer batch per slice,
  merges, deploys, and product feedback.
