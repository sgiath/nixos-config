# Evaluate workflow decisions

These tabletop cases exercise agent decisions, not application behavior. They are reusable
instruction evaluations, not production regression tests and not a replacement for executable
gates. Keep prompts separate from [rubrics](rubrics.md) so actors do not see the expected answer.
No service, source checkout from a scenario, or external write is available to the actor.

## Cases

| Prompt | Decision under test |
| --- | --- |
| [review-assumptions](prompts/review-assumptions.md) | Review the goal/design and falsify scope and identity assumptions. |
| [runtime-revision](prompts/runtime-revision.md) | Distinguish worktree HEAD from code loaded by a process. |
| [checker-contract](prompts/checker-contract.md) | Preserve acceptance checks and settled product decisions. |
| [clean-run](prompts/clean-run.md) | Reject a flow repaired through the database during verification. |
| [input-side-effects](prompts/input-side-effects.md) | Check real input assumptions and prove write effects safely. |
| [resume-record](prompts/resume-record.md) | Retain compact local evidence and verify it on resumption. |
| [small-task](prompts/small-task.md) | Avoid imposing this workflow on an immediate metadata edit. |
| [blocked-gate](prompts/blocked-gate.md) | Preserve the user's authority over unavailable required proof. |
| [expensive-gate](prompts/expensive-gate.md) | Settle inputs, then measure one fixed commit outside the live checkout. |
| [harness-controls](prompts/harness-controls.md) | Exercise the whole harness on controls before paid runs. |
| [small-ui-routing](prompts/small-ui-routing.md) | Route a small bug fix by role instead of by apparent size. |
| [generated-brief](prompts/generated-brief.md) | Keep generated briefs from inventing a routing exemption. |
| [unchanged-wake](prompts/unchanged-wake.md) | Post nothing on an unchanged scheduled tick. |

## Run a comparison

Use the host's delegated-task tools and live model catalog. Apply verified-work's routing:
supporting evaluation delegates use Codex `gpt-6.1-sol` on the fast tier. Use the same model,
effort, prompts, steering and tool permissions in both arms. Each actor gets a fresh context and
one case, with no parent discussion or previous answer. Bound each task and overall run using
the host's task lifecycle; a timeout is Inconclusive, never Pass. No task may keep running or
write in the scenario's fictional environment.

`small-ui-routing` and `generated-brief` test a Claude thread's routing choice, so their actors run as
Claude Opus 5.5. `unchanged-wake` also gives the actor the drive snapshot entrypoint.

1. Before editing, freeze the relevant skill catalog and references outside the tracked tree.
   Preserve the source revision and any dirty patch. After editing, freeze the candidate too.
   A snapshot must include references needed for `skill://` resolution, not just the entrypoint.
2. For every case, run one actor on the pre-edit snapshot and another on the candidate. Give
   each only the snapshot entrypoints, allowed references and that case's prompt. Save exact
   responses/tool traces outside the repository. Actors must not see rubrics, the other arm,
   implementation discussion, or a live/installed skill copy that differs from the snapshot.
3. Grade the anonymized responses against the frozen rubric in a fresh read-only context. Give
   the judge the prompt, rubric and actual response/trace, without which arm produced it or the
   expected improvement. Require Pass, Fail or Inconclusive per case with a deciding quote and
   reason. The owner inspects disputed results and records any adjudication explicitly.
4. Report every case and both arms, model/effort/tier, snapshot identities, inherited steering
   limits, task IDs and raw artifact paths. Missing responses, read failures and unavailable
   tooling are Inconclusive. A completed actor task alone is not a passing evaluation.

Actor brief, with paths substituted by the owner:

```text
Read the supplied verified-work and own-change snapshot entrypoints and only the linked
references needed for this scenario. Resolve skill references inside that snapshot; do not
read live/installed copies, evaluation rubrics or other cases. Then answer the supplied case
prompt as the agent at that decision point, within its length limit. This is a tabletop
exercise: do not operate the fictional repository/services, delegate, publish or modify source.
Return the actual next actions or brief requested. Save the exact answer at the supplied local
result path, the only file you may write. Do not discuss the evaluation in the answer.
```

For the initial adoption or an affected workflow edit, run the relevant cases and both scope
controls (`small-task`, `blocked-gate`); run all cases for changes to shared gates/handoffs. Keep
unchanged scenarios as regression controls even when both arms pass. A case that already passed
before the edit does not demonstrate an improvement. One stochastic run is a smoke check;
repeat disputed or unstable results with a new actor and retained prior results, not a new rubric.

The pre-edit arm measures the change to this setup, not the benefit of having any skills at all.
For a no-skill comparison, use a genuinely clean harness without implicit copies of these
instructions, disclose remaining steering, and omit the workflow catalog. If the harness cannot
isolate it, report that limitation rather than claim a no-skill baseline.

## Maintain the cases

Add a realistic decision point when an observed failure warrants an instruction change. Use the
facts available to the agent at that point without hinting at the answer. Give the rubric a
concrete observable decision to grade, including plausible correct alternatives. Do not grade
headings, stock phrases or a fixed implementation when outcomes are equivalent.

Freeze prompts and rubrics before comparing instructions. If a scenario or rubric itself is
wrong or ambiguous, explain the correction and rerun both arms; do not adjust it merely to pass
the candidate. Preserve meaningful baseline failures and rerun them after the fix. Do not
manufacture a red test for an instruction edit. Enforce mechanical rules through appropriate
deterministic checks; run metadata and skill-reference validation separately.
