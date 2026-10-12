---
name: drive
disable-model-invocation: true
description: "Manual only: /drive plan, replan, or a plan directory turns a spec note into ordered slices and drives eligible slices through worker threads. Never auto-trigger."
---

# Drive a plan of slices

Run ONLY when the user invokes `/drive` or explicitly asks to drive a plan. This skill replaces the user acting as a for-loop over agent sessions: it starts the next slice, relays nothing by hand, and asks the user only for decisions, merges and deploys.

Invoking it authorizes: committing plan files, launching worker threads that run `own-change` (worktrees, commits, pushes, PRs, babysitting), recording answers and deploy markers in the plan's state directory, and scheduling the driver's own wake-ups. It does not authorize merging, deploying, running migrations, or pushing plan changes before the user approves them. The user merges and deploys every slice.

The driver needs T3 Code thread launch/read/send, PR inventory and scheduler tools. Use live tool documentation;
if discovery is lazy, make one bounded `orchestrator_capabilities` call before reporting missing capabilities.
This workflow explicitly authorizes separate top-level workers; read-only research/review remains delegated child work.

Use skill://verified-work for verifiable step design, handoffs, integration gates and blocker decisions. Drive owns
delivery order and worker lifecycle; workers own each slice's executable gates. A required reproduction/gate that
cannot be established or met needs the user's decision. Relay it once, stop dependent slices, and never treat it
as a stopped worker to restart, an automatic replan, or a limitation that counts as completion.

## Artifacts

- **Spec**: Agent Notes in the repository, as usual. Decisions and architecture only, never progress.
- **Plan**: `.agents/plans/<yyyy-mm-dd>-<topic>/` with `plan.md` and one `NN-<slug>.md` per slice. Format and templates: [plan format](references/plan-format.md). For tracked plans, only planning (on the default branch) and a slice's own PR edit these files. If the user or plan requires local artifacts, keep the plan, answers and spec unpublished; only the driver edits them and workers read absolute local paths. Do not copy them into implementation commits.
- **Delivery state**: derived on every wake-up by [`scripts/plan-status <plan-dir>`](scripts/plan-status) from slice files, GitHub PRs or GitLab MRs on the exact slice branches, local branches, and the deploy check. Run it against the original absolute plan directory independently of worker checkouts. It does not read behavioral gate records. Never cache delivery state in the conversation or write progress into the repository.
- **State directory** (outside the repository, printed by `plan-status` as `state_dir`): `asked/NN.md` (questions and recommendations sent to the user), `answers/NN.md` (initial slice decisions), `deployed/NN` (deploy marker), `gates/NN.md` (driver-owned verification evidence and later gate decisions), `final-gate.md` (plan integration evidence), `traps.md` (friction workers hit, appended by workers).

For each gate record, keep the acceptance claim, status (`passed`, `failed`, `blocked` or `pending`), applicable
revision/environment, artifact paths, exact commands/results, and any pending question or dated user decision.
The driver updates it from worker evidence and the user's answers, not from PR/merge status. Record a relayed gate
question here before yielding and preserve it until answered; initial `answers/NN.md` does not answer a later blocker.

## `/drive plan @<spec-note> [more notes…]`

1. Read the notes and the code they touch. Cut the work into slices: each is one PR-sized, independently deployable deliverable (plus companion PRs such as a db-schemas migration) with an executable acceptance gate and a stop boundary. Apply verified-work within a slice rather than creating a delivery slice for every experiment. Identify the final integration gate that proves the plan's Goal. Put a "local testing with production-like data" slice first when the feature needs one and none exists.
2. Mark `blocked_by` only for real dependencies, and for every one: a slice that changes code only meaningful after another slice ships (a prompt for a path that slice adds) is blocked by it, so slices that run in parallel each work on master alone. Set `deploy_gate: false` only when later slices do not need the slice running in production. Set `migration: true` for any schema change.
3. Write each slice's "Questions before starting": the decisions the worker must not guess. Leave them unanswered.
   For each question, cite the spec line or gap that leaves it open, and drop questions the spec, standing rules or
   code already decide. Resolve a spec contradiction from existing decisions when possible; otherwise ask the user
   rather than choosing a changed requirement. Put decisions that affect more
   than one slice into `plan.md` Standing rules.
4. The last slice in order also moves the tracked spec notes to `implemented/` (per the repository's notes rules). For local artifacts, the driver performs that move and link repair locally after the last slice is done. It is
   blocked by every other slice so parallel work cannot finalize the notes early. Retain the plan directory as
   delivery scope and question records: `plan-status` needs it to verify completion. Removal is a separate requested
   cleanup after the driver has stopped, not part of the final worker's PR.
5. Show the user one table (id, title, blocked by, deploy gate, migration) and the open questions per slice. Apply corrections. When the user approves, commit the tracked plan on the default branch and push it. Local plans stay on this machine; pass their absolute paths and slice scope/answers to workers rather than expecting the plan on the remote default branch.

## `/drive replan [findings]`

Fold new findings, production data, stakeholder input or a changed order into the plan. Never renumber existing slices; numbers are stable names and the `order` list in `plan.md` is the delivery order. Add new slices with the next free number, delete dropped ones. A slice that is `in_progress` or `in_review` keeps running unless the change invalidates it; then ask the user whether to stop its worker. Show the diff of the plan, then commit and push tracked plans on approval; local plans remain unpublished. Delete `answers/NN.md` for any slice whose questions changed.

## `/drive @<plan-dir>`: start or resume

The thread where this runs is the driver thread. It holds no implementation code; coordination evidence lives in
the state directory so a fresh thread with the same command continues correctly. Run one tick, then only if its finish step still requires future coordination,
create or retain a `schedule_task` bound to this thread, structured
`schedule: {type: "interval", everyMs: 900000}`, with the prompt `Run one drive tick for @<plan-dir> (skill drive,
section Tick).` Keep exactly one schedule per plan: list scheduled tasks first and reuse an existing one. Retain
its ID, use a stable creation retry key, and report the returned cadence and next run time when creating it. Do not
recreate a schedule after the tick stopped for completion or user answers. PR waits belong to each
worker's persistent watcher. End the turn after the tick; do not keep a shell sleep/poll loop alive.

## Tick

1. Run `scripts/plan-status <absolute-plan-dir>` from the skill directory and read `plan.md`. The script chooses `gh` or `glab` from origin and uses explicit slice `branch` values when present. Find worker threads with `t3_thread_list` (`titleContains: "<topic> NN"`). Apply verified-work's role routing: production workers and production-design reviews use Claude Opus 5.5; evidence/reproduction/verification delegates use Codex `gpt-6.1-sol`. Honor task-specific overrides and the user's effort choice for workers and descendants.
   Read `gates/NN.md` for every slice with a worker, PR or delivered dependency, regardless of its delivery status.
   Refresh records from relevant worker messages/artifacts. For an older plan without records, recover applicable
   evidence from its owners rather than assuming a merge proves the gate or rerunning valid checks blindly.
   A missing record is unverified until recovered. Request achievable missing verification from its owner;
   relay an unachievable gate once under verified-work, recording the question here. Pending/blocked gates remain
   unresolved even when the script reports `merged`, `done` or `complete`.
2. **Closed slices**: a slice with an unmerged closed required PR and none open needs the user. Ask once whether to relaunch, replan or drop it; a merged companion does not complete it.
3. **Workers that stopped early** (`in_progress`, thread no longer running, no PR): read recent thread messages,
   queued follow-ups and pending user questions. Workspace preparation, queued work or live delegated children are
   waiting states, not stopped work. If a question is already answered in `answers/NN.md` or current user context,
   respond through `t3_pending_request_respond` when available; otherwise relay it once with the thread link. Never
   infer an answer or approve permissions. An unachievable reproduction/verification gate is a blocker even if no
   host question card exists: read the worker's gate/attempts/options, relay the decision once, and preserve its
   pending question. Do not resend or replace that worker until the user answers. If no wait/blocker exists, send the worker back once naming the unmet
   step, with a stable `clientRequestId`; if it stops again, hand it to the user. Before sending back or replacing
   a failed or cancelled worker, list provider processes whose working directory is the slice worktree (`pgrep`,
   `/proc/<pid>/cwd`) and compare them with `recentRuns`; a cancelled run can still be running.
   - A cancelled run can leave its provider process alive and still committing/pushing. If a worker reports another
     session or unexplained commits, identify the actual provider processes, start times and working directories
     and compare them with `recentRuns` from `t3_thread_read`. Report the unmatched process with that evidence
     once; repeat it only if it pushes again, and in the Finish summary. Do not kill it or restart work while two
     agents can push to one branch.
   - **Missing worker** (`in_progress` or `in_review`, no surviving worker thread): this slice is not in `next`,
     so recover it here. Search thread inventory including settled workers and inspect any known PR watches,
     queues/children and provider processes for the checkout. Reuse a surviving task thread when possible. If none
     owns the work, verify the branch, task changes, PR/head and absolute checkout path, then launch one replacement
     with `workspaceStrategy: {type: "existing_worktree", worktreePath: "<path>", branch: "<slice-branch>"}`.
     Supply the worker prompt plus the existing PRs, completed checks and outstanding findings; it resumes rather
     than restarting the slice. If the branch has no checkout, prepare one using native support for existing branches
     when available, otherwise Worktrunk, then bind the replacement to it. Do not create a replacement while another
     owner is active or ownership is uncertain. Apply the same retained-ID/ambiguous-launch recovery rules as step 8.
4. **Slices in review**: an idle worker with an active T3 PR watch (GitHub) or a running `babysit-mr` monitor
   (GitLab) is waiting normally, not stopped early. Read
   `list_thread_pull_requests` for its thread and its last messages; do not send it back merely because CI/review
   is pending. When every PR is merge-ready (all checks/reviewers complete and green, no unresolved actionable
   threads, Evidence present, the screenshot or recording required by PR policy for UI changes) and the worker handed it back, tell the user once:
   `NN <title> ready to merge: <PR URLs>`, plus companion merge order and any migration. If it handed back an
   incomplete PR without a watcher, send it back once with the specific agent-actionable gap; relay genuine blockers.
   Readiness includes the slice's actual acceptance gate and any user-approved limitation; green CI alone is insufficient.
   Send independent verification findings directly to the implementation owner and request affected gates again.
   On GitLab, once an MR's CI is green and before it is marked ready, launch one `$self-review` thread per MR with
   the production-judgment model from verified-work's routing or the user's task-specific override, and send its findings to the implementer thread; after the fixes the
   implementer requests `$self-review update` the same way. The user should not have to relay findings.
5. **Cleanup**: when a slice is `merged` or `done`, verify all companion PRs are merged and no worker, child task,
   queued continuation or watcher still uses its checkouts. Require its gate record to be passed and retain any
   checkout/artifacts still needed for unresolved dependent or final integration verification. Use native removal if available; otherwise read the
   `worktrunk` skill and use `wt remove <branch>` from a different checkout in each repository. Do not remove a
   dirty or active checkout; report why it remains. Deleting/settling a T3 thread does not remove its worktree.
6. **Merged slices waiting for deploy**: `deploy_check` in `plan.md` decides. Without one, ask the user once to say when it is deployed; when they do, write `deployed/NN` in the state directory. Never treat a merge as a deploy.
7. **Ask ahead** (`ask_ready` and `ask_next` in the status): ground the whole ready group's unanswered questions, plus the next eligible blocked slice's questions, in current code and production data with a read-only research subagent. Ask them together in one numbered message with a recommended answer each; consolidate shared decisions and map them back to each slice. When the evidence does not fit a short message, put it with the recommendations into a rendered page and ask one question: accept all, or list exceptions. Write the questions and recommendations you sent to `asked/NN.md`; `plan-status` then lists the slice in `awaiting_answers` and stops offering it, so never ground or ask it again. Before asking or recording answers, read the user's messages since the last ask; if an answer could refer to two different recommendation sets, confirm which. Write the user's answers to each `answers/NN.md` verbatim with the date. A slice with no questions gets `answers/NN.md` containing `No questions.`
8. **Launch** every eligible slice in `next` whose `answers/NN.md` exists, up to `parallel`: resolve its exact branch and verified remote default
   base, then inspect existing worker threads/worktrees to avoid duplicates. Before launching, require every
   `blocked_by` dependency's gate record to be passed as well as its delivery/deploy prerequisite; the script's
   `next` list alone is insufficient. Do not launch a slice with its own unresolved gate question. For new work, call `t3_thread_launch`
   in this project with `workspaceStrategy: {type: "worktree", baseRef: "<default-branch>", branch: "<slice-branch>",
   startFromOrigin: true}`, title `<topic> NN: <title>`, and `message` from the [worker prompt](references/worker-prompt.md). Fill in its placeholders and add context, but never
   drop its steps (review subagent, host workflow, traps).
   To resume an existing task checkout, use `existing_worktree` with its verified absolute path and branch.
   Retain the returned thread ID; a preparing launch is not a failed worker. After a lost/ambiguous response, inspect
   thread inventory before retrying; launch has no retry key. Post one line: `Started NN <title>: <thread link>`.
   An explicit empty branch awaits its real issue/branch; do not invent one. Independent MRs awaiting review consume only the configured capacity, not a group barrier. For local artifacts, supply absolute plan/answer paths and scope in the launch context and forbid workers from publishing them. Use the repository's host workflow: GitLab repositories publish with their template, authenticated-user assignment and GitLab skills; do not route them through `gh` or GitHub-only publication steps.
   Let the finish step decide whether a tick schedule remains necessary after this launch.
9. **Traps**: after a slice is done, read `traps.md`. When it holds the same trap twice, or every five finished slices, propose permanent fixes the way the `retro` skill does (check, reviewer rule, steering edit, skill change, tooling), each with the exact file it touches. Skip traps that already have a `decided` line. Apply nothing; the user picks. Record each decision in `traps.md` as `- <date> decided: <trap> -> applied <commit>` or `-> declined`, and never propose a declined fix again.
10. **Finish**: when `complete` is true, verify `gates/NN.md` and `final-gate.md` against current applicable evidence before claiming
    the Goal is complete; `plan-status` tracks delivery, not behavioral proof. If a required gate is unmet and cannot
    be met, ask the user how to proceed. Delete the schedule when no independent work remains and the plan only
    waits for that answer; do not recreate it on the same tick. When all required gates pass, delete the schedule,
    post a summary (slices, PRs, user-approved limitations) and the trap proposals. When nothing is running, in review
    or waiting for deploy and the plan only waits for user answers, delete the schedule too; the reply wakes the driver.

Keep driver messages to one line per event. Do not narrate ticks where nothing changed.

## Ad hoc work

Fixes the user starts outside the plan (screenshots, Slack requests) do not edit plan files. If one changes what a pending slice assumes, the user says `/drive replan`.
