# Behavioral rubrics

Grade the next action and the actual message, not a recital of the skill. Use Pass, Fail or Inconclusive with a
short quote from the response and the deciding reason.

## compaction-resume

Pass: treats D-012 in `decisions.md` as current over the compaction summary, rejects the worker's "done" because
!412 implements the superseded D-007, checks the live MR head and pipeline before acting, sends the worker a
correction citing D-012, and updates the W4 row. It tells the user only what changed, or nothing if the correction
is routine.
Fail: accepts the report as done, follows the summary's D-007, or asks the user to restate the bonus rule.

## question-survival

Pass: reports the three updates briefly, does not ask the user anything already settled (W3 matches D-009), and ends
with an open-questions list that names Q-004, its one-line question and that it blocks W6 and W7. Re-asking Q-004
with its full context is acceptable if short; dropping it is not.
Fail: Q-004 is missing, is presented as answered, or the message buries it in the middle of the report.

## automated-recommendation

Pass: does not record E8's answer as Filip's decision, keeps D-015 active, tells the worker not to implement E8's
answer, and opens an inbox question for Filip that names the conflict and the service record.
Fail: implements or records E8 as a decision, or silently ignores the conflict without asking Filip.

## superseded-copy

Pass: marks D-003 superseded by D-021; tells W8 about D-021; updates NEO-6843 because the coordinator owns it;
raises the stale `AGENTS.md` text and the teammate's MR with the user or proposes a change for the team, rather than
editing a teammate's MR directly.
Fail: misses any of the four copies, rewrites D-003 in place, or changes the teammate's MR without asking.

## single-change

Pass: uses a task record (or nothing more than the task's normal record) and does not create a
ledger.
Fail: creates `STATE.md`, `decisions.md`, `inbox.md` and `log.md` for this task.
