# A local record for resumption

Use a short record when substantial work will cross a context boundary, wait, or handoff. A
small immediate edit does not need one. Reuse a task's existing plan/state when it already holds
this information; Drive owns its existing gate records and delivery state.

For an ordinary single change, choose a task-specific directory under
`${XDG_STATE_HOME:-$HOME/.local/state}/agent-work/<repository>/<task>/` and record its absolute
path in the thread/handoff. Give concurrent tasks distinct directories even when they share a
branch. Keep records and evidence outside tracked files; do not put progress in an Agent Note,
commit it, or replace Home Manager-managed files. Secrets belong in their credential store,
not in this record. Record evidence paths and access prerequisites rather than credentials.

Use only the fields needed below. Rewrite current state in place; a large activity log and run
metrics are optional, not requirements.

```markdown
# <observable outcome>

Goal and source: <request/contract link or concise requirement>
Checkout: <absolute path>; branch <branch>; base <revision>; current <revision and dirty patch>
Authority and stop boundary: <allowed actions and where this task stops>
Status and next action: <what happens next, owner, and any wait>

Decisions and assumptions:
- <who decided what, why, source; evidence for consequential input assumptions>

Gates:
- <claim>: <passed/failed/blocked/pending>; <tested revision/build/environment>;
  <exact command/result and runnable fixture/output paths>; <limits or applicability to current code>

Review:
- <finding, source, disposition and evidence, or outstanding decision>

Pending questions:
- <question already asked, attempts, recommendation; dated user answer when received>

Publication, if authorized: <PR URLs, pushed heads, watcher ownership and outstanding checks>
```

Update it when a decision, revision, gate, review disposition, publication or next action changes,
and before handing off. Link it when the user or another owner needs resumption evidence; do not
repeat its full contents in every progress message.

On resumption, read the record and raw evidence, then check the actual checkout path/branch,
dirty state and relevant commits, including unpushed work. Inspect running processes/builds and
host PR state where applicable. The record is a recovery aid, not authority over newer user
instructions or proof that live state stayed unchanged. Preserve the tested revision and explain
any valid reuse across later commits. Do not restart an owner or watcher merely because it waits.
Retain the record and runnable evidence while review, handoffs or unresolved gates need them.
