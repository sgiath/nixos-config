# Worker prompt

<!-- FIXME: GitLab MRs avoid `watch_pull_request` because T3 cannot read them yet (2026-10-09: 47 of 47 watch
     notifications in neo failed). Revisit when a T3 update supports GitLab MR watches. -->

The driver launches each slice with this message, filled in. Use absolute plan/state paths; a local plan lives outside the worker checkout. Include its slice scope and answers in the launch context when needed. Select the repository's host workflow. Apply verified-work's role routing and preserve task-specific provider/model/effort overrides for all descendants.

```text
/own-change Implement slice <NN> of the plan @<plan-dir>/plan.md: @<plan-dir>/<NN>-<slug>.md

- T3 has already selected the primary task worktree on branch <branch> from the verified remote default branch. Verify the binding and reuse it; do not create another worktree or hand off again. Companion repositories use the same branch name and their own verified remote default base.
- The user's answers to this slice's questions: @<state-dir>/answers/<NN>.md. For tracked artifacts, record them under "Questions before starting" in the slice file in this PR, and move any decision they change into the spec note. For local artifacts, report decisions to the driver; do not modify, copy, commit or publish plan/spec/answer files.
- Known traps from earlier slices: @<state-dir>/traps.md. Read it before starting.
- Use skill://verified-work within this slice: validate its checks, implement only the Deliverable, prove the Acceptance gate and relevant integration behavior, and stop at the Stop boundary. Do not create a second delivery plan.
- Route roles by skill://verified-work unless the user has overridden them for this task: Claude Opus 5.5 for production design and implementation; Codex `gpt-6.1-sol` on the fast tier for investigation, reproductions, throwaway scripts, executable verification and the independent review of the diff (high effort); Claude Fable 5.1 only for designing new UI.
- External calls and credentials: <for each paid or rate-limited API/model the slice calls: the credential source (env var or file), the approved model, and the ceiling as N runs / N calls or "unlimited"; or "none">. Count calls as you make them and stop before passing a ceiling. "Unlimited" means do not ask for more. Start runs before approval only when this line does not say the run plan needs approval.
- Ask the driver only about a requirement that is still unresolved: name it, the spec or answer line that leaves it open, and your recommendation. A choice the ticket, spec, answers or code already determines is a finding to report; report it and continue without waiting.
- Run expensive gates (real runs, paid evaluations, benchmarks, multi-minute suites) only after the reviews that can change their inputs or code, from a checkout of one fixed commit that nobody edits, and record that commit when the run starts (verified-work runtime checks).
- If a required reproduction or verification gate cannot be established or met, send the driver the gate, attempts, missing prerequisite and recommended options. Stop dependent work and ask how to proceed; the driver relays the question once. Do not silently narrow the gate or publish the work as complete.
- Send actual gate results, revision/environment and artifact paths to the driver for its local gates/NN.md record before handoff. If this slice owns the plan's Final integration gate, include that result for final-gate.md as well. Later gate questions and answers are separate from initial slice decisions; do not mark a blocked gate passed because the PR merged.
- Give every subagent verified-work's handoff record, the absolute worktree path and the files it owns. Collect findings and coordinate fixes/reverification directly without user relay.
- Before opening PRs, run a read-only review subagent over the diff against the base and fix valid findings. Discover providers/models with orchestrator_capabilities; use native subagents where supported or delegate_task for cross-provider/T3-owned review. Give it the original request, acceptance checks, settled decisions, absolute paths, base/current revisions and raw evidence. Follow verified-work's independent-review reference: judge the reading of the request, usefulness, design and concrete data assumptions before code correctness; ask it to form its own assessment before reading the implementer's justification. Async completion wakes this thread. Every further delegated review round is a new task with prior findings and responses, not a message to its child thread.
- UI changes need the screenshot or recording required by the PR policy. Prefer T3 preview status/open, snapshots and focused interactions; retain the runnable fixture and media needed for review, and label simulated dependencies.
- Do not merge, deploy, or run migrations; finish at merge-ready.
- For GitHub, publish through the global pr skill and use babysit-pr. When waiting for CI/review, use T3's persistent watcher and yield; resume on notifications. Do not run `gh run watch` or other shell polling loops.
- Never end a turn on a background shell wait: T3 settles an idle thread and the background completion does not wake it. Wait for CI/review with the host's monitor (T3's PR watcher on GitHub, the repository's babysit-mr on GitLab); wait for deploys, rollouts or test suites with one foreground command bounded by a timeout.
- Start long-lived services a gate needs (dev nodes, gate clients, Xvfb) detached with `setsid` and a recorded PID, not with the tool's background mode, which kills them at its two-hour limit; stop them by that PID.
- For GitLab, use the repository's gitlab-access/babysit-mr skills, its complete MR template and authenticated-user assignment; override own-change's GitHub publication steps. Wait with the repository's babysit-mr monitor, not `watch_pull_request`: T3 cannot read GitLab MRs yet.
- Link every PR/MR through T3. Watcher waits are not a completed slice.
- If a decision outside the answers blocks you, ask it and stop; do not guess.
- When done, append each friction you hit (a failed check you could have predicted, a missing pointer, a repeated workaround) to @<state-dir>/traps.md as `- <date> <NN>: <trap> -> <what would have prevented it>`, once per slice; skip entries already there. Append nothing if there was none.
```
