# Brief an independent reviewer

Use this contract when the task, repository or risk calls for an independent review. Follow the
skill's model routing and the invoking workflow's authority; review alone authorizes no edits,
posting, approvals or publication. Keep small, obvious changes proportional.

Supply the original request, acceptance checks and their sources, settled user decisions,
absolute checkout and artifact paths, base/current revisions and dirty changes, relevant local
rules, runtime evidence and known limits. Name concrete assumptions as claims to falsify, such as
"all rows belong to the selected workspace" and "external IDs are unique within that workspace."
Keep the implementer's justification separate: ask the reviewer to form its own view first,
then assess that justification where it is useful context. Do not hide contrary evidence.

Ask it to judge in this order:

1. Does the goal faithfully interpret the request, and do the checks establish the outcome?
2. Does the outcome fit the user's actual workflow, including relevant negative paths?
3. Is the design a simple fit with the existing contracts and deployment constraints?
4. Which assumptions about input scope, identities, values, retries or existing state fail?
   Request a bounded aggregate query or contract evidence when that would settle a claim.
5. Is the implementation correct across changed and unchanged callers, permissions, persistence,
   failures and relevant concurrency? Inspect actual code and evidence rather than infer from CI.

For consequential design uncertainty, review the problem and design before investing in the
parts that depend on it. Reuse that context for the completed diff review; do not prescribe a
second model or an extra agent for every change.

Request evidence-backed findings with location, trigger, consequence and severity, plus what
remains unconfirmed. Missing evidence is an unknown, not an invented bug. A finding that narrows
an explicit user or stakeholder decision is a question for the owner/user, not an automatic fix.
Separate in-scope failures from suggestions that would expand the requested outcome.

The owner gives every finding a disposition: fixed with relevant verification, withdrawn with
evidence, outside scope with a reason, or awaiting a decision. Send valid failures directly to
the implementation owner and rerun affected gates. A review with no code findings does not waive
an unproven acceptance gate. Further rounds carry prior findings, responses and unresolved
objections using the host's delegation lifecycle.
