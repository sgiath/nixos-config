# Worker prompt

<!-- FIXME: GitLab MRs avoid `watch_pull_request` because T3 cannot read them yet (2026-10-09: 47 of 47 watch
     notifications in neo failed). Revisit when a T3 update supports GitLab MR watches. -->

The driver launches each slice with this message, filled in. Use absolute plan/state paths; a local plan lives outside the worker checkout. Include its slice scope and answers in the launch context when needed. Select the repository's host workflow and preserve the user's provider/model/effort restrictions for all descendants.

```text
/own-change Implement slice <NN> of the plan @<plan-dir>/plan.md: @<plan-dir>/<NN>-<slug>.md

- T3 has already selected the primary task worktree on branch <branch> from the verified remote default branch. Verify the binding and reuse it; do not create another worktree or hand off again. Companion repositories use the same branch name and their own verified remote default base.
- The user's answers to this slice's questions: @<state-dir>/answers/<NN>.md. For tracked artifacts, record them under "Questions before starting" in the slice file in this PR, and move any decision they change into the spec note. For local artifacts, report decisions to the driver; do not modify, copy, commit or publish plan/spec/answer files.
- Known traps from earlier slices: @<state-dir>/traps.md. Read it before starting.
- Implement only the Deliverable, prove the Acceptance gate, and stop at the Stop boundary.
- Give every subagent the absolute worktree path and the files it owns.
- Before opening PRs, run a read-only review subagent over the diff against the base and fix valid findings. Discover providers/models with orchestrator_capabilities; use native subagents where supported or delegate_task for cross-provider/T3-owned review. Give it the task, acceptance gate, absolute paths, diff base and actual checks. Async completion wakes this thread. Every further delegated review round is a new task with prior findings and responses, not a message to its child thread.
- UI changes need a browser screenshot in the PR's Evidence. Prefer T3 preview status/open, snapshots and focused interactions; save screenshot/recording paths when useful.
- Do not merge, deploy, or run migrations; finish at merge-ready.
- For GitHub, publish through the global pr skill and use babysit-pr. When waiting for CI/review, use T3's persistent watcher and yield; resume on notifications. Do not run `gh run watch` or other shell polling loops.
- For GitLab, use the repository's gitlab-access/babysit-mr skills, its complete MR template and authenticated-user assignment; override own-change's GitHub publication steps. Wait with the repository's babysit-mr monitor, not `watch_pull_request`: T3 cannot read GitLab MRs yet.
- Link every PR/MR through T3. Watcher waits are not a completed slice.
- If a decision outside the answers blocks you, ask it and stop; do not guess.
- When done, append each friction you hit (a failed check you could have predicted, a missing pointer, a repeated workaround) to @<state-dir>/traps.md as `- <date> <NN>: <trap> -> <what would have prevented it>`, once per slice; skip entries already there. Append nothing if there was none.
```
