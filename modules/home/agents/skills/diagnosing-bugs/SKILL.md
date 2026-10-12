---
name: diagnosing-bugs
description: Investigate hard-to-reproduce bugs or performance regressions that need a controlled feedback loop to distinguish causes.
---

# Diagnosing bugs

Use a symptom-specific reproduction to distinguish causes, then verify the fix against the original scenario. A routine error with an established cause does not need this workflow.

Use skill://verified-work for acceptance gates, handoffs and blockers; this skill supplies the diagnostic methods.
Preserve an existing task plan rather than starting a second workflow. A requested investigation can finish with
evidence and unknowns; it does not authorize a fix or publication.

## Routes

- Need a reproduction: [choose a seam](references/feedback-loop.md#choose-a-reproduction-seam), including trace replay, differential runs, bisection, fuzzing, and the [human-assisted template](scripts/hitl-loop.template.sh).
- Intermittent failure or unavailable environment: [establish the failure signal](references/feedback-loop.md#establish-the-failure-signal) covers reproduction rates and missing prerequisites.
- Need to distinguish causes or measure a regression: [minimize and discriminate](references/feedback-loop.md#minimize-and-discriminate).
- Ready to change code: [fix and verify](references/feedback-loop.md#fix-and-verify) defines regression seams and completion evidence.

Redact secrets in every command, output, and captured artifact you show: write `<REDACTED>`, keep credentials in environment variables used by the loop, and quote only the lines of a capture that carry the signal.

Before causal experiments, have a command already exercised against the reported symptom or a faithful synthetic
scenario, with its output recorded. Label injected conditions and distinguish a matching mechanism from a confirmed
natural trigger. Accept reported failures as evidence. Do not claim a cause or fix from a nearby failure or a passing
check that cannot detect this bug. If a required reproduction cannot be established, ask the user how to proceed
under verified-work; documenting a limitation does not waive the gate.

For a requested fix, completion includes the required reproduction passing, meaningful regression coverage,
comparable measurements for flaky/performance cases, removal of temporary instrumentation, and the supported cause.
A missing required seam or unmet gate needs the user's decision, not a silent completion exception. Ask for missing
access or production-instrumentation permission when it blocks the loop; do not require an extra review pause
between executable experiments.
