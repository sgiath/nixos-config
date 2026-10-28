---
name: verified-work
description: "Use for substantial implementation or investigation to split work into verifiable steps, validate the checks, and coordinate completion. A trivial edit or narrow lookup does not need this workflow."
---

# Work through verifiable steps

Own the requested outcome, including evidence gathering, handoffs and verification. Choose the steps from the
uncertainties and observable contracts of the task; there is no universal sequence or required number of agents.
Select this skill automatically when substantial implementation or investigation is requested; no explicit invocation is needed.
Use a single check for a small task. For larger work, separate claims that can be checked independently, then
check their integration. Do not split by files or frontend/backend layers when neither piece proves useful behavior.

## Establish the gates

Before changing behavior, identify the requested outcome, acceptance criteria and authorized stop boundary.
Read the supplied evidence and relevant implementation. Distinguish observations, hypotheses and product decisions.
Resolve decisions already settled by the request or repository; ask about unresolved decisions that affect correctness.

Name the assumptions the change relies on: input scope, identifier uniqueness, value meanings and existing state.
Before building on a consequential data assumption, check the producer contract, enforced schema or representative
real input with bounded read-only queries; a convenient seed is not evidence of the input's actual shape. Record
the source and any remaining uncertainty. Do not retrieve personal data when counts or distributions suffice.
For importers, backfills and other data-writing tools, include both intended writes and triggered effects
(callbacks, jobs, notifications, webhooks, syncs) in the gates; prove them locally as described in
[runtime checks](references/runtime-checks.md#data-writing-tools).

For each necessary step, identify:

- The observable claim and its independent source of expected results: requirements, captured evidence,
  a worked example, an existing contract or a known-good baseline.
- The smallest artifact that makes the claim checkable: fixture, replay, synthetic page, test, query or benchmark.
- The executable check, required environment, expected result and dependencies on earlier gates.
- What the check cannot establish, including injected conditions and substituted dependencies.

Keep this in the task's existing plan or a short local working record when handoffs/resumption need it.
Use the [local record format](references/run-record.md) for substantial single changes that need durable state;
reuse Drive's existing state instead of creating a parallel record. Do not create a tracked plan, Agent Note or
new framework for every task. Update the record when evidence changes the necessary steps; preserve the requested
outcome and explain any changed gate.

Validate the check before relying on it. A bug reproduction must reach the relevant production path and match
the reported symptom, with a normal control where useful. Inject a plausible condition at a dependency boundary,
not the wrong result into the code being tested. Record the actual red run. A refactor uses behavior comparisons;
a performance task uses a comparable measured baseline. Do not manufacture a failing test for an instruction edit.
An exit code without an assertion about the claimed behavior is not verification.

A synthetic reproduction can establish a matching failure mechanism without establishing the customer's natural
trigger. Preserve that distinction through implementation and delivery. A successful synthetic check does not
automatically satisfy a gate requiring the original device, live dependency or production environment.

## When a gate cannot be established or met

A red test is expected work: investigate and fix it within the authorized scope. Pending builds, delegated tasks
and CI are bounded waits, not requests for user decisions. Correct actionable setup/tool errors and try reasonable
alternative seams or controlled fixtures before declaring a blocker.

If no faithful reproduction/check can be established, or a required gate cannot be met with a practical route
within the authorized scope and access, **ask the user how to proceed**. Include the gate, attempts and observed
failure, missing prerequisite, what remains unknown, and concrete options with a recommendation. Options may be
providing access/evidence, approving a narrower synthetic or hypothesis-only deliverable, changing scope, or stopping.

Stop work that depends on that gate until the user answers. Continue only independent authorized work that does
not assume it passed. Do not silently weaken assertions, replace the gate with a nearby passing check, call a
documented limitation a waiver, or publish the result as complete. A delegate reports the blocker to its owner;
the owner asks once and records the answer. Time passing is not an answer. Preserve artifacts for resumption.

An unattended scheduled run has nobody to ask. Its task prompt is the user's answer in advance: use the authority
it grants, record anything beyond it as a blocker with the gate, evidence and options, and continue with
independent work instead of waiting.

When the user changes or explicitly accepts a limited gate, record the decision and the remaining limitation.
If the same unresolved blocker persists, keep the question pending rather than restarting experiments or asking
again. New evidence or an answer can reopen the loop.

## Route work by role

Unless the user chooses differently for this task, use these provider/model pairs. Route by role even when the
current thread could do a phase itself: an Opus thread delegates exploration, investigation, reproduction and
verification to Codex, and a Codex thread delegates the production change to Claude.

| Work | Provider/model |
| --- | --- |
| Everything that is not production code: code exploration, research, investigation, evidence gathering, causal experiments, brute-force exploration, fuzzing/bisection, reproductions including the failing test that captures the defect, throwaway tests and scripts, production-data probes, screenshots, executable verification, and CI or review-failure triage | Codex with `gpt-6.1-sol` |
| Independent review of a complicated fix or PR, including production-code correctness and design judgments | Codex with `gpt-6.1-sol` at `high` reasoning effort |
| Once the handoff is ready: deciding where and how to fix the production code, production design and seam placement, production code, refactoring, existing UI changes that do not require a new design, and turning the handed-over failing test into the committed regression test | Claude with Opus 5.5 (`claude-opus-5-5` in the live catalog) |
| Creating and designing new UIs or substantial redesigns where visual and UX judgment adds value, including animations and transitions | Claude with `fable-5-1` at `xhigh` reasoning effort |

Use Fable sparingly because it is expensive. Limit its scope to design and implementation that requires those
design choices. Routine UI updates, bug fixes, investigation, testing, screenshots, review and verification use
the general Opus/Codex routing; touching a UI does not route a phase or its descendants to Fable.

Codex establishes causes and compares measured alternatives; Claude judges the production change from that
evidence. Hand work to Claude only when it is ready: the cause is established with evidence, the reproduction
exists (a failing test in the repository's test layer where one fits, with its red run) and the verification
commands are written, so the remaining question is where and how to change production code. Opus reads the code it
needs for that decision and runs the handed-over test and the repository's required checks while writing the
change. Investigation, exploratory scripts and the final verification go back to Codex. When the diagnosis does
not hold, Opus reports that to the owner for another Codex investigation instead of investigating itself.
Exploration scripts stay disposable. Turning one into shipped tooling, or applying an exploratory patch to production,
is production implementation and belongs to Claude. Codex's thoroughness is also useful when a complicated fix
or PR needs an independent review: that review can judge production-code correctness and design, not just run
empirical checks. Opus owns the resulting production changes.

The current thread remains the owner regardless of its model. It does a phase directly only when its model
matches that phase's role; coordination, briefs and instruction or metadata edits need no delegate. When a phase
requires another model, delegate that bounded phase with its gate, evidence and explicit ownership rather than
asking the user to move threads. Reuse valid evidence across the handoff; do not repeat investigation merely to
change providers. Pure instruction/metadata edits and coordination do not require a production-code delegate.

Resolve provider instances and exact model IDs from `orchestrator_capabilities`; use the requested provider,
not another harness that happens to expose the same model. Honor task-specific provider/model/effort overrides
for the roles they cover; selecting a composer model alone does not override this role routing. If the required
provider/model or delegation route is unavailable, report the attempts and ask how to proceed before doing that
phase. Do not silently substitute another model. Continue independent work on available roles.

## Execute and hand off

One owning thread coordinates the work and remains responsible for the final outcome. This workflow permits
bounded child tasks for evidence gathering, reproduction, implementation or independent verification within the
user's authorized task. Delegate when a fresh context or independent check is useful; do not require a new agent
for every step. Give implementation delegates explicit file/checkout ownership and prevent concurrent writers.
Apply the role routing above to every phase and descendant; discover provider instances and available model IDs
from the live host catalog rather than assuming the current provider or its native model list is sufficient.

Use delegated child tasks for phases. Separate top-level threads, persistent schedules and publication need the
user's request or an explicitly invoked workflow that authorizes them. In T3 use native delegation where supported
or `delegate_task`, retain task IDs and yield for async completion. Each new delegated review round is a new task
with the original brief, earlier findings, responses and unresolved objections; do not restart it by messaging
its backing child thread. For existing user-owned cooperating threads, keep one implementation owner and send
findings directly rather than asking the user to relay them.

Each handoff carries the goal and gate, authority/stop boundary, absolute checkout and artifact paths, base/current
revision, setup and exact commands, actual results, injections, unresolved claims and next action. Supply enough
raw evidence for an independent verifier to inspect it; a conclusion-only summary is insufficient. Keep stable
fixtures and expected outcomes available across revisions. Do not let an implementer redefine success to fit a fix;
a necessary fixture change must preserve the contract and have its sensitivity rechecked.

For an independent review, use the [review brief](references/independent-review.md): test the reading of the request,
the usefulness of the outcome, the design and concrete assumptions before code correctness. Give the reviewer
requirements and raw evidence so it can form its own assessment before reading the implementer's justification.
This supplies the review contract when a review is needed; it does not require a reviewer for every task.

Collect findings, send valid in-scope failures back to the implementation owner, and rerun affected gates without
user relay. Ask about scope/product decisions and unachievable gates using the rule above. Reuse completed checks
when their code, inputs, environment and claim remain applicable; a changed revision invalidates affected evidence.

## Complete the requested outcome

Check the complete scenario after the individual pieces pass. Choose relevant interactions from the code:
persisted state, failure/retry, cancellation, concurrent attempts, old payloads or rolling deployment may need
verification. A unit test of one caller does not establish a multi-caller or asynchronous workflow invariant.
For running apps, services and CLIs, follow [runtime checks](references/runtime-checks.md): establish what code the
running process loaded, preserve the agreed checks in verifier briefs, and rerun any attempt interrupted by a
repair. Exercise plausible adjacent actions separately from acceptance requirements.

Before handing back, account for every required gate as passed, failed, blocked or pending, with commands/results
and revision where applicable. A required failed, blocked or pending gate prevents a completion claim. Report
synthetic versus original-scenario evidence, remaining unknowns and any user-approved limitation. Retain runnable
evidence needed for review/handoffs outside disposable setup; commit only useful production regression tests or
reproductions that belong in the requested deliverable. Do not delete the sole copy before a recipient can use it.

## Compose with other skills

This skill owns gates, blockers and handoffs. Consult other skills for their part without restarting this workflow:

- skill://diagnosing-bugs supplies reproduction seams and causal experiments when the cause is uncertain.
- skill://tdd supplies behavioral test design and the red/green implementation loop. Establish a reproduction
  first when needed; plan gates up front, then implement one verified behavior at a time rather than all tests first.
- skill://video-evidence extracts supplied recordings; it does not turn an observed symptom into a diagnosis.
- skill://research applies when a source-cited repository research note is requested, not to every evidence lookup.
- skill://pr owns requested publication; skill://babysit-pr owns GitHub CI/review waiting and readiness.
  Read-only reviews and description-only edits use existing evidence and do not authorize implementation.
- skill://own-change and skill://drive own their explicitly invoked execution/publication scope. Keep them manual;
  this skill neither invokes them implicitly nor grants commit, push, merge, deploy or production-mutation authority.

Repository policy supplies local contracts and checks. Do not waive a gate because another skill allows reporting
a limitation; use the blocker rule unless the user has already accepted that limitation for this task.

When changing these workflow instructions, use the [behavioral evaluations](evals/README.md) to check decisions
against realistic scenarios, alongside metadata and reference validation. These are bounded tabletop checks,
not live application verification and not an instruction to evaluate every ordinary implementation task.
