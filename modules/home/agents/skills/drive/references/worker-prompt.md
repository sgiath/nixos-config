# Worker prompt

The driver launches each slice with this message, filled in. Pass pointers, not copies: the worker reads the files itself.

```text
/own-change Implement slice <NN> of the plan @<plan-dir>/plan.md: @<plan-dir>/<NN>-<slug>.md

- Branch: <branch> in every repository you touch (companion repositories use the same branch name). Base it on the remote default branch.
- The user's answers to this slice's questions: @<state-dir>/answers/<NN>.md. Record them under "Questions before starting" in the slice file in this PR, and move any decision they change into the spec note.
- Known traps from earlier slices: @<state-dir>/traps.md. Read it before starting.
- Implement only the Deliverable, prove the Acceptance gate, and stop at the Stop boundary.
- Give every subagent the absolute worktree path and the files it owns.
- Before opening PRs, run a read-only review subagent (use the code-review skill if available) over the diff against the base and fix valid findings.
- UI changes need a browser screenshot in the PR's Evidence.
- Do not merge, deploy, or run migrations; finish at merge-ready.
- If a decision outside the answers blocks you, ask it and stop; do not guess.
- When done, append each friction you hit (a failed check you could have predicted, a missing pointer, a repeated workaround) to @<state-dir>/traps.md as `- <date> <NN>: <trap> -> <what would have prevented it>`. Append nothing if there was none.
```
