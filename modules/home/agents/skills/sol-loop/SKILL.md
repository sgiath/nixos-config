---
name: sol-loop
description: "Use when the user says 'sol loop': review the current change with Codex gpt-6.1-sol in rounds, fixing findings until it approves."
---

# Sol loop

Review the current change with one reviewer, Codex `gpt-6.1-sol` at `high` reasoning effort, and loop until it
approves. Resolve the exact model through `orchestrator_capabilities`; if Sol is unavailable, report it and do not
substitute another model.

Write the brief from verified-work's [review brief](../verified-work/references/independent-review.md) and follow
its review rounds: fixed scope, read-only reviewer, severities, ledger, budget and stop rules. Start each round as a
new `delegate_task` carrying the original brief and the ledger; do not message the backing child thread. Production
fixes follow verified-work's role routing.

The invocation authorizes fixing findings within the task's scope. Do not push during the loop. After agreement,
push only when the user asked to push, ship or update the PR.
