# Agent Note: Opus does its own short work, Sol takes long and independent work

Status: implemented

## Problem

From 2026-10-25 the shared instructions sent all work before and around a production change to Sol: code
exploration, research, investigation, reproduction, the failing test and verification. From 2026-10-30 this
applied "however small the change looks" and explicitly outranked the harness's advice to make a few tool calls
directly. Opus threads then delegated within a median of about a minute and five tool calls, including plain
questions and lookups, and waited on the result.

The T3 thread history (`~/.t3/userdata/statev2.sqlite`, 2,354 completed Opus→Sol delegations since
2026-10-10) and CLIProxy usage (`agents.cliproxy_requests`) showed the cost on 2026-11-18:

- The median active time of a user request in an Opus thread rose from 2.2 to 6.3 minutes, and the 75th
  percentile from 6.4 to 32 minutes, as the share of requests using Sol rose from 6% to about 45%. The task
  mix also changed over that period, so this is a correlation.
- A Sol call took a median of 13.4 s at about 32 output tokens/s; an Opus call took 9.7 s at about 57 tokens/s.
- Investigation subagents took a median of 12.3 minutes on Sol and 5.5 minutes as Opus's own subagents.
  Reviews took about 6 minutes on either model.
- In requests that used Sol, Opus itself was active for 1-3 minutes. Since the move to the OpenCode harness,
  the Opus thread sat idle for a median of 75% of the request, waiting on the delegate.
- Sol reviews returned findings in 617 of 853 rounds. Long investigations whose time goes into repeated test
  or build runs (for example an 11-minute serial suite run to confirm a flaky test) gained from Sol's
  thoroughness at little latency cost.

## Decision

[`verified-work`](../../../../modules/home/agents/skills/verified-work/SKILL.md) and the shared
[`AGENTS.md`](../../../../modules/home/agents/AGENTS.md) route by the value of independence and thoroughness
instead of by phase:

- The current thread does its own reading, lookups, answers to questions, short investigations, a red test it
  can write and run quickly, and quick checks. A small fix can stay in an Opus thread from diagnosis to its own
  red/green run.
- Sol takes long-running or brute-force evidence work, the independent final verification of a substantial
  change, a second diagnosis when the cause stays uncertain or the first one did not hold, and side
  investigations that run while the owner keeps working.
- Sol at `high` effort reviews every production change beyond a few obvious lines before hand-back or
  publication, not only complicated ones.
- Opus writes production code; a Sol thread delegates production code to Opus with the cause, reproduction
  and verification commands.
- While a delegate runs, the owner continues independent work and ends the turn only when nothing
  independent remains.

Drive's worker brief, `own-change` and `research` apply the same routing. The verified-work evaluation cases
`small-ui-routing` and `generated-brief` now grade the new decision, and `long-evidence-routing` guards the
other direction: long repeated runs still go to Sol.

## Alternatives considered

- Keep phase routing and only parallelize better. Sol would still be slower per step, re-read what the owner
  read for the brief, and answer questions that needed no delegate.
- Send exploration to a cheap fast model, as poteto's pstack does with Composer. No such model is part of this
  setup, and Opus's own short work was already faster than the handoff.
- Use Sol only for user-invoked reviews, as t3dotgg's tstack does. That leaves spare GPT usage unused and
  drops the cross-family check on ordinary changes, which found real issues.
- Start investigation-heavy threads on Sol directly. This remains available per task and avoids the handoff,
  but it is the user's choice when starting a thread, not a routing rule.

## Consequences

Short requests in Opus threads should return to minutes rather than tens of minutes. GPT usage moves to
reviews, verification and long evidence work. More changes get an independent Sol review, which adds about
six minutes per round on those changes. The decision supersedes the phase routing recorded in
[Verifiable steps and agent ownership](2026-10-10-verifiable-agent-work.md); the rest of that note stands.
Its OpenCode harness and Opus-only default are in turn superseded by
[Native harnesses and updated model routing](2026-11-23-native-harnesses-and-model-routing.md), while the
short-work-in-thread vs long-work-to-Sol split remains.

Revisit with the same queries if Sol's per-call latency approaches Opus's, or if Opus-only investigations
start missing causes that Sol would have found.
