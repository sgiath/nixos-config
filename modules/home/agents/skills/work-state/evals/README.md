# Evaluate work-state decisions

Tabletop cases for the coordinator's decisions at the points where the Spain G2N sprint lost or misused state.
Keep prompts separate from [rubrics](rubrics.md) so actors do not see the expected answer. Run comparisons with the
procedure in [verified-work's evals](../../verified-work/evals/README.md#run-a-comparison), giving actors this
skill's snapshot instead of verified-work's.

| Prompt | Decision under test |
| --- | --- |
| [compaction-resume](prompts/compaction-resume.md) | Resume from the ledger, not from a stale summary, and check live state. |
| [question-survival](prompts/question-survival.md) | Keep an unanswered question visible while worker reports arrive. |
| [automated-recommendation](prompts/automated-recommendation.md) | Refuse to record a service's recommendation as the user's decision. |
| [superseded-copy](prompts/superseded-copy.md) | Find and fix stale copies of a superseded decision. |
| [single-change](prompts/single-change.md) | Do not start a ledger for one ordinary change. |
