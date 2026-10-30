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

## Run review rounds

Fix known issues, address outstanding PR comments and run the covering checks before the first round, so the
reviewer sees the current implementation; report missing or already failing checks in the brief. Fix the reviewed
change once: run `git status --short`, never stash, discard or include unrelated work, and take the base from
`git merge-base HEAD origin/<base-branch>` after `git fetch`. The change is base to working tree including untracked
files; use the same diff command in every round.

Each reviewer is read-only: it does not edit, commit, push, comment on PRs or start subagents. Do not edit the
reviewed paths while a round runs. A timeout, error or empty reply is not approval. Ask for a verdict, `APPROVE` or
`CHANGES`, and for findings with stable ids, each labeled:

- `blocker`: the intended case is wrong.
- `should`: a real bug callers will hit within the intended scope.
- `nit`: everything else, including other paths, rare cases, small performance costs, extra compatibility, and
  code, tests or guards the intent does not need.

Check every finding and its severity yourself. Another path, a rare case or a small cost is a nit whatever label
it came with. Fix agreed findings with the smallest change, preferring deletion or narrowing over a new lock, cache,
helper or option. Disagree with evidence (file:line, test, output). Decline out-of-scope findings and nits in one
line and list them as follow-ups. Do not agree just to end the loop. If review grew the diff, cut it first.

Keep a ledger of id, severity and disposition across rounds. The budget is three rounds; extend it to five only
while an evidenced blocker or should stays open in security, permissions, data loss or state/concurrency, or when
the user asks. Start another round only when a blocker or should is open or behavior changed since the reviewer
last approved; comment, documentation and format-only fixes need none. A later round gets the original brief,
the ledger with responses and the change since the last round, and checks open ids and changed code only.

Stop when every reviewer approves the current behavior diff, no blocker or should is open and you have no concern
of your own. When an item stays disputed after two replies, or the budget ends, show both sides in two or three
lines each and let the user decide; an exhausted budget is not approval. Report the rounds, models, fixed and
declined findings with reasons, and the diff size before and after.
