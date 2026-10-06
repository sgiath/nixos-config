---
name: drive
disable-model-invocation: true
description: "Manual only: /drive plan|replan|<plan-dir> turns a spec note into ordered slices and drives them one PR at a time through worker threads. Never auto-trigger."
---

# Drive a plan of slices

Run ONLY when the user invokes `/drive` or explicitly asks to drive a plan. This skill replaces the user acting as a for-loop over agent sessions: it starts the next slice, relays nothing by hand, and asks the user only for decisions, merges and deploys.

Invoking it authorizes: committing plan files, launching worker threads that run `own-change` (worktrees, commits, pushes, PRs, babysitting), recording answers and deploy markers in the plan's state directory, and scheduling the driver's own wake-ups. It does not authorize merging, deploying, running migrations, or pushing plan changes before the user approves them. The user merges and deploys every slice.

The driver needs T3 Code tools (`t3_thread_launch`, `t3_thread_list`, `t3_thread_read`, `t3_thread_send`, `schedule_task`, `delete_scheduled_task`). If they are missing, say so and stop.

## Artifacts

- **Spec**: Agent Notes in the repository, as usual. Decisions and architecture only, never progress.
- **Plan**: `.agents/plans/<yyyy-mm-dd>-<topic>/` with `plan.md` and one `NN-<slug>.md` per slice. Format and templates: [plan format](references/plan-format.md). Only planning (on the default branch) and a slice's own PR edit these files.
- **State**: derived on every wake-up by [`scripts/plan-status <plan-dir>`](scripts/plan-status) from slice files, GitHub PRs on the slice branches, local branches, and the deploy check. Never cache it in the conversation and never write progress into the repository.
- **State directory** (outside the repository, printed by `plan-status` as `state_dir`): `answers/NN.md` (the user's answers to a slice's questions), `deployed/NN` (marker when the user reports a deploy that `deploy_check` cannot see), `traps.md` (friction workers hit, appended by workers).

## `/drive plan @<spec-note> [more notes…]`

1. Read the notes and the code they touch. Cut the work into slices: each is one PR-sized, independently deployable deliverable (plus companion PRs such as a db-schemas migration) with an acceptance gate a reviewer can check and a stop boundary. Put a "local testing with production-like data" slice first when the feature needs one and none exists.
2. Mark `blocked_by` only for real dependencies. Set `deploy_gate: false` only when later slices do not need the slice running in production. Set `migration: true` for any schema change.
3. Write each slice's "Questions before starting": the decisions the worker must not guess. Leave them unanswered.
4. The last slice in order also moves the spec notes to `implemented/` (per the repository's notes rules) and deletes the plan directory.
5. Show the user one table (id, title, blocked by, deploy gate, migration) and the open questions per slice. Apply corrections. When the user approves, commit the plan on the default branch and push it. Workers branch from the remote default branch and cannot see unpushed plan files.

## `/drive replan [findings]`

Fold new findings, production data, stakeholder input or a changed order into the plan. Never renumber existing slices; numbers are stable names and the `order` list in `plan.md` is the delivery order. Add new slices with the next free number, delete dropped ones. A slice that is `in_progress` or `in_review` keeps running unless the change invalidates it; then ask the user whether to stop its worker. Show the diff of the plan, then commit and push on approval. Delete `answers/NN.md` for any slice whose questions changed.

## `/drive @<plan-dir>`: start or resume

The thread where this runs is the driver thread. It holds no code and no state of its own; a fresh thread with the same command continues correctly. Run one tick, then create a `schedule_task` bound to this thread, `{type: "interval", everyMs: 900000}`, with the prompt `Run one drive tick for @<plan-dir> (skill drive, section Tick).` Keep exactly one such schedule per plan: list scheduled tasks first and reuse an existing one.

## Tick

1. Run `scripts/plan-status <plan-dir>` from the skill directory and read `plan.md`. Find worker threads with `t3_thread_list` (`titleContains: "<topic> NN"`).
2. **Closed slices**: a slice whose PRs were all closed unmerged needs the user. Ask once whether to relaunch, replan or drop it.
3. **Workers that stopped early** (`in_progress`, thread no longer running, no PR): read the thread's last messages. If the worker is waiting on a decision, relay the question to the user verbatim with the thread link. Otherwise send the worker back once with `t3_thread_send` naming the unmet step; if it stops again, hand it to the user.
4. **Slices in review**: when the worker thread has finished and every PR is merge-ready (all checks complete and green, no unresolved actionable threads, Evidence present in the body, a screenshot for UI changes), tell the user once: `NN <title> ready to merge: <PR URLs>`, plus the merge order for companion PRs and any migration they need to run. If the worker finished but the PR is not merge-ready, send the worker back once with the specific gap.
5. **Cleanup**: when a slice is `merged` or `done`, remove its worktrees with `wt remove <branch>` in each repository it touched (read the `worktrunk` skill). Leave a worktree with uncommitted changes in place and tell the user.
6. **Merged slices waiting for deploy**: `deploy_check` in `plan.md` decides. Without one, ask the user once to say when it is deployed; when they do, write `deployed/NN` in the state directory. Never treat a merge as a deploy.
7. **Ask ahead** (`ask_next` in the status): ground that slice's questions in current code and production data with a read-only research subagent, then ask the user all of them in one numbered message with a recommended answer each. Write the user's answers to `answers/NN.md` verbatim with the date. A slice with no questions gets `answers/NN.md` containing `No questions.`
8. **Launch** each slice in `next` whose `answers/NN.md` exists: `t3_thread_launch` in this project, `workspaceStrategy: {type: "root"}`, title `<topic> NN: <title>`, message from the [worker prompt](references/worker-prompt.md). Post one line: `Started NN <title>: <thread link>`. Recreate the tick schedule if step 10 deleted it.
9. **Traps**: after a slice is done, read `traps.md`. When it holds the same trap twice, or every five finished slices, propose permanent fixes the way the `retro` skill does (check, reviewer rule, steering edit, skill change, tooling), each with the exact file it touches. Apply nothing; the user picks.
10. **Finish**: when `complete` is true, delete the schedule, post a summary (slices, PRs, anything unverified) and the trap proposals. When nothing is running, in review or waiting for deploy and the plan only waits for the user's answers, delete the schedule too; the user's reply wakes the driver.

Keep driver messages to one line per event. Do not narrate ticks where nothing changed.

## Ad hoc work

Fixes the user starts outside the plan (screenshots, Slack requests) do not edit plan files. If one changes what a pending slice assumes, the user says `/drive replan`.
