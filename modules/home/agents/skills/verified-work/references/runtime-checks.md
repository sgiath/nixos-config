# Verify the running change

Apply these checks to runtime behavior: UI flows in the actual app, service behavior through real
requests, and CLI behavior through the installed or built command under test. A docs-only or
instruction-only change does not acquire an app gate. Use the host's browser/device tools and
repository setup; this reference does not mandate a browser or a new verification agent.

## Establish the runtime and starting state

Record the source revision and any uncommitted patch that the build includes, the relevant
configuration and fixtures, and how the process or artifact was built and started. Confirm that
the answering process loaded that code: use a build/version endpoint, build metadata, or a
verified build/start log tied to the checkout and executable. Worktree HEAD alone proves nothing
about an already-running server, CLI on PATH, or cached frontend bundle. Reload/rebuild/restart
as needed and inspect the actual served artifact; do not invent a version endpoint requirement.

Establish each check's starting state before the attempt, using isolated seeded identities and
records where available. Do not change another run's shared settings or fixtures. Identify local
receivers for external effects and retain any limits caused by substituted dependencies.

## Brief and run the checks

Give a verifier the agreed Given/When/Then checks without changing their triggers or outcomes,
plus how to reach them, the seeded user/role or credentials through the appropriate private
channel, runtime revision/build evidence, fixture paths and expected outputs. Include settled
decisions that exclude seemingly plausible features. Keep exploration separate from acceptance
checks: it may find failures, but it must not silently add new requirements.

Use the real entry point for the gate. Prepare data before the attempt; an unplanned database
edit, flag flip, dependency substitution or code fix used to repair a failed attempt invalidates
that attempt. Preserve the failure, fix its cause, reset to a controlled starting state, then
rerun the complete affected check without repair. Planned state changes that the scenario itself
tests are valid actions. Record exploratory failure triggers so the owner can reproduce them.

Keep runtime code and fixtures stable during a check. Coordinate concurrent writers and hot
reloads; queue fixes until the attempt ends. If they change underneath it, rerun the affected
check. Try plausible adjacent actions relevant to the change: refresh/back, another supplied
role, invalid input, repeated submission or overlapping requests. Choose from actual behavior;
this is not an exhaustive checklist for every change.

## Evidence and later revisions

Record pass/fail/blocked per check with expected/actual results, runtime identity and raw evidence
(screenshots/video for UI where useful or required, request/response or command output otherwise).
Inspect captures yourself: a blank frame or final database value after a repair is not flow
proof. Keep runnable fixtures available for the next owner. Use the publication skill's hosting
rules when attaching media; local paths alone are not embedded PR evidence.

After a behavior change, rerun affected checks and replace media that depicts changed behavior.
Reuse earlier evidence only with an explicit applicability reason: unchanged code path, inputs,
configuration and dependencies. A comment-only commit need not restart a service. Keep the
original tested revision visible; never relabel an old capture as proof of a newer runtime.
An unavailable required runtime gate follows the skill's blocker rule.

## Data-writing tools

Before implementation, establish actual input scope, matching-key uniqueness and relevant value
meanings from contracts, enforced constraints or representative read-only aggregates. A seed
covering one workspace cannot prove that a real file contains only that workspace. If a required
assumption cannot be checked, preserve it as unknown and follow the blocker rule for dependent work.

List the intended row changes and what saving can trigger: callbacks, jobs, notifications,
webhooks and syncs. Prove selection with a local dry run/non-writing preview where useful, or
equivalent independent assertions alongside a controlled local execution. Exercise a real local
write through the production entry point to prove the effects. Do not add preview machinery when
the controlled execution already proves selection. A transaction rollback does not undo an
emitted webhook or email.

Capture expected/actual row and job counts and requests received by local sinks, including
expected zero effects. Exercise a relevant invalid input and retry, and verify both target
records and untouched neighboring scope. A no-write preview cannot prove save callbacks.
Use isolated local data and safe receivers/queues; do not deliver real notifications or write
production data without separate authorization. State what the stand-ins cannot prove and keep
any separately required live integration gate.
