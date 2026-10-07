---
name: drive
disable-model-invocation: true
description: "Manual only: /drive plan|replan|<plan-dir> turns a spec note into ordered slices and drives eligible slices through worker threads. Never auto-trigger."
---

# Drive a plan of slices

Run ONLY when the user invokes `/drive` or explicitly asks to drive a plan. This skill replaces the user acting as a for-loop over agent sessions: it starts the next slice, relays nothing by hand, and asks the user only for decisions, merges and deploys.

Invoking it authorizes: committing plan files, launching worker threads that run `own-change` (worktrees, commits, pushes, PRs, babysitting), recording answers and deploy markers in the plan's state directory, and scheduling the driver's own wake-ups. It does not authorize merging, deploying, running migrations, or pushing plan changes before the user approves them. The user merges and deploys every slice.

The driver needs T3 Code thread launch/read/send, PR inventory and scheduler tools. Use live tool documentation;
if discovery is lazy, make one bounded `orchestrator_capabilities` call before reporting missing capabilities.
This workflow explicitly authorizes separate top-level workers; read-only research/review remains delegated child work.

## Artifacts

- **Spec**: Agent Notes in the repository, as usual. Decisions and architecture only, never progress.
- **Plan**: `.agents/plans/<yyyy-mm-dd>-<topic>/` with `plan.md` and one `NN-<slug>.md` per slice. Format and templates: [plan format](references/plan-format.md). For tracked plans, only planning (on the default branch) and a slice's own PR edit these files. If the user or plan requires local artifacts, keep the plan, answers and spec unpublished; only the driver edits them and workers read absolute local paths. Do not copy them into implementation commits.
- **State**: derived on every wake-up by [`scripts/plan-status <plan-dir>`](scripts/plan-status) from slice files, GitHub PRs or GitLab MRs on the exact slice branches, local branches, and the deploy check. Run it against the original absolute plan directory independently of worker checkouts. Never cache it in the conversation and never write progress into the repository.
- **State directory** (outside the repository, printed by `plan-status` as `state_dir`): `answers/NN.md` (the user's answers to a slice's questions), `deployed/NN` (marker when the user reports a deploy that `deploy_check` cannot see), `traps.md` (friction workers hit, appended by workers).

## `/drive plan @<spec-note> [more notes…]`

1. Read the notes and the code they touch. Cut the work into slices: each is one PR-sized, independently deployable deliverable (plus companion PRs such as a db-schemas migration) with an acceptance gate a reviewer can check and a stop boundary. Put a "local testing with production-like data" slice first when the feature needs one and none exists.
2. Mark `blocked_by` only for real dependencies, and for every one: a slice that changes code only meaningful after another slice ships (a prompt for a path that slice adds) is blocked by it, so slices that run in parallel each work on master alone. Set `deploy_gate: false` only when later slices do not need the slice running in production. Set `migration: true` for any schema change.
3. Write each slice's "Questions before starting": the decisions the worker must not guess. Leave them unanswered.
4. The last slice in order also moves the tracked spec notes to `implemented/` (per the repository's notes rules). For local artifacts, the driver performs that move and link repair locally after the last slice is done. It is
   blocked by every other slice so parallel work cannot finalize the notes early. Retain the plan directory as
   delivery scope and question records: `plan-status` needs it to verify completion. Removal is a separate requested
   cleanup after the driver has stopped, not part of the final worker's PR.
5. Show the user one table (id, title, blocked by, deploy gate, migration) and the open questions per slice. Apply corrections. When the user approves, commit the tracked plan on the default branch and push it. Local plans stay on this machine; pass their absolute paths and slice scope/answers to workers rather than expecting the plan on the remote default branch.

## `/drive replan [findings]`

Fold new findings, production data, stakeholder input or a changed order into the plan. Never renumber existing slices; numbers are stable names and the `order` list in `plan.md` is the delivery order. Add new slices with the next free number, delete dropped ones. A slice that is `in_progress` or `in_review` keeps running unless the change invalidates it; then ask the user whether to stop its worker. Show the diff of the plan, then commit and push tracked plans on approval; local plans remain unpublished. Delete `answers/NN.md` for any slice whose questions changed.

## `/drive @<plan-dir>`: start or resume

The thread where this runs is the driver thread. It holds no code and no state of its own; a fresh thread with the
same command continues correctly. Run one tick, then only if its finish step still requires future coordination,
create or retain a `schedule_task` bound to this thread, structured
`schedule: {type: "interval", everyMs: 900000}`, with the prompt `Run one drive tick for @<plan-dir> (skill drive,
section Tick).` Keep exactly one schedule per plan: list scheduled tasks first and reuse an existing one. Retain
its ID, use a stable creation retry key, and report the returned cadence and next run time when creating it. Do not
recreate a schedule after the tick stopped for completion or user answers. PR waits belong to each
worker's persistent watcher. End the turn after the tick; do not keep a shell sleep/poll loop alive.

## Tick

1. Run `scripts/plan-status <absolute-plan-dir>` from the skill directory and read `plan.md`. The script chooses `gh` or `glab` from origin and uses explicit slice `branch` values when present. Find worker threads with `t3_thread_list` (`titleContains: "<topic> NN"`). Honor the user's provider/model/effort choice for every worker and delegated descendant.
2. **Closed slices**: a slice with an unmerged closed required PR and none open needs the user. Ask once whether to relaunch, replan or drop it; a merged companion does not complete it.
3. **Workers that stopped early** (`in_progress`, thread no longer running, no PR): read recent thread messages,
   queued follow-ups and pending user questions. Workspace preparation, queued work or live delegated children are
   waiting states, not stopped work. If a question is already answered in `answers/NN.md` or current user context,
   respond through `t3_pending_request_respond` when available; otherwise relay it once with the thread link. Never
   infer an answer or approve permissions. If no wait/blocker exists, send the worker back once naming the unmet
   step, with a stable `clientRequestId`; if it stops again, hand it to the user.
   - A cancelled run can leave its provider process alive and still committing/pushing. If a worker reports another
     session or unexplained commits, identify the actual provider processes, start times and working directories
     and compare them with `recentRuns` from `t3_thread_read`. Report the unmatched process with that evidence;
     do not kill it or restart work while two agents can push to one branch.
   - **Missing worker** (`in_progress` or `in_review`, no surviving worker thread): this slice is not in `next`,
     so recover it here. Search thread inventory including settled workers and inspect any known PR watches,
     queues/children and provider processes for the checkout. Reuse a surviving task thread when possible. If none
     owns the work, verify the branch, task changes, PR/head and absolute checkout path, then launch one replacement
     with `workspaceStrategy: {type: "existing_worktree", worktreePath: "<path>", branch: "<slice-branch>"}`.
     Supply the worker prompt plus the existing PRs, completed checks and outstanding findings; it resumes rather
     than restarting the slice. If the branch has no checkout, prepare one using native support for existing branches
     when available, otherwise Worktrunk, then bind the replacement to it. Do not create a replacement while another
     owner is active or ownership is uncertain. Apply the same retained-ID/ambiguous-launch recovery rules as step 8.
4. **Slices in review**: an idle worker with an active T3 PR watch is waiting normally, not stopped early. Read
   `list_thread_pull_requests` for its thread and its last messages; do not send it back merely because CI/review
   is pending. When every PR is merge-ready (all checks/reviewers complete and green, no unresolved actionable
   threads, Evidence present, a screenshot for UI changes) and the worker handed it back, tell the user once:
   `NN <title> ready to merge: <PR URLs>`, plus companion merge order and any migration. If it handed back an
   incomplete PR without a watcher, send it back once with the specific agent-actionable gap; relay genuine blockers.
5. **Cleanup**: when a slice is `merged` or `done`, verify all companion PRs are merged and no worker, child task,
   queued continuation or watcher still uses its checkouts. Use native removal if available; otherwise read the
   `worktrunk` skill and use `wt remove <branch>` from a different checkout in each repository. Do not remove a
   dirty or active checkout; report why it remains. Deleting/settling a T3 thread does not remove its worktree.
6. **Merged slices waiting for deploy**: `deploy_check` in `plan.md` decides. Without one, ask the user once to say when it is deployed; when they do, write `deployed/NN` in the state directory. Never treat a merge as a deploy.
7. **Ask ahead** (`ask_ready` and `ask_next` in the status): ground the whole ready group's unanswered questions, plus the next eligible blocked slice's questions, in current code and production data with a read-only research subagent. Ask them together in one numbered message with a recommended answer each; consolidate shared decisions and map them back to each slice. Write the user's answers to each `answers/NN.md` verbatim with the date. A slice with no questions gets `answers/NN.md` containing `No questions.`
8. **Launch** every eligible slice in `next` whose `answers/NN.md` exists, up to `parallel`: resolve its exact branch and verified remote default
   base, then inspect existing worker threads/worktrees to avoid duplicates. For new work, call `t3_thread_launch`
   in this project with `workspaceStrategy: {type: "worktree", baseRef: "<default-branch>", branch: "<slice-branch>",
   startFromOrigin: true}`, title `<topic> NN: <title>`, and `message` from the [worker prompt](references/worker-prompt.md).
   To resume an existing task checkout, use `existing_worktree` with its verified absolute path and branch.
   Retain the returned thread ID; a preparing launch is not a failed worker. After a lost/ambiguous response, inspect
   thread inventory before retrying; launch has no retry key. Post one line: `Started NN <title>: <thread link>`.
   An explicit empty branch awaits its real issue/branch; do not invent one. Independent MRs awaiting review consume only the configured capacity, not a group barrier. For local artifacts, supply absolute plan/answer paths and scope in the launch context and forbid workers from publishing them. Use the repository's host workflow: GitLab repositories publish with their template, authenticated-user assignment and GitLab skills; do not route them through `gh` or GitHub-only publication steps.
   Let the finish step decide whether a tick schedule remains necessary after this launch.
9. **Traps**: after a slice is done, read `traps.md`. When it holds the same trap twice, or every five finished slices, propose permanent fixes the way the `retro` skill does (check, reviewer rule, steering edit, skill change, tooling), each with the exact file it touches. Apply nothing; the user picks.
10. **Finish**: when `complete` is true, delete the schedule, post a summary (slices, PRs, anything unverified) and the trap proposals. When nothing is running, in review or waiting for deploy and the plan only waits for the user's answers, delete the schedule too; the user's reply wakes the driver.

Keep driver messages to one line per event. Do not narrate ticks where nothing changed.

## Ad hoc work

Fixes the user starts outside the plan (screenshots, Slack requests) do not edit plan files. If one changes what a pending slice assumes, the user says `/drive replan`.
