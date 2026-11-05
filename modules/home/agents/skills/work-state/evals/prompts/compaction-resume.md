You coordinate a payroll engine sprint and your context was just compacted. The compaction summary says: "Bonus
is spread evenly over the year (D-007). W4 implements it in MR !412." The ledger at /state/payroll/sprint/ contains:

- decisions.md: D-007 "Bonus spread evenly over the year", status superseded, superseded by D-012. D-012 (user,
  yesterday) "Bonus is paid whole in its payment month", status active.
- STATE.md: W4 row, MR !412, head 9f1c2aa, status "in progress, implementing D-012".

A worker message now arrives: "W4 done. !412 at head 77ab301 spreads the bonus evenly as specified. Pipeline green."

Say what you do next and what, if anything, you tell the user. Keep it under 250 words. Do not write files.
