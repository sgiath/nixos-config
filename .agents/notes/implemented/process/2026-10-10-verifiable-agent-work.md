# Agent Note: Verifiable steps and agent ownership

Status: implemented

## Problem

Specialized skills cover diagnosis, test design, publication and delivery, but
none owns the evidence contract across those phases. Passing unit tests, green
CI or a merged slice can conceal an unverified interaction. Evidence can also
disappear when temporary fixtures are cleaned up before another agent uses them.
The user then has to coordinate threads and notice incomplete verification.

## Decision

The shared instructions select
[`verified-work`](../../../../modules/home/agents/skills/verified-work/SKILL.md)
for substantial implementation and investigation. It owns acceptance gates,
validated checks, handoffs and blocker decisions. Specialized skills retain
their methods and scope without starting a second workflow.

Steps follow observable claims and uncertainties rather than a fixed sequence
or agent count. Each check has an independent expected result and states its
limits. A synthetic reproduction can establish a matching failure mechanism;
it does not establish a customer's natural trigger. Required integration checks
remain part of completion after individual steps pass.

One thread owns the outcome and coordinates bounded child tasks and valid
findings without user relay. When required proof cannot be established or met
within available scope and access, the owner asks the user how to proceed and
stops dependent work. A documented limitation is not a waiver.

The user's default role split assigns investigations, brute-force exploration,
throwaway scripts and executable verification to Codex with `gpt-6.1-sol`.
Claude with Opus 5.5 judges production design and fix placement, writes
production code and adds durable regression tests. The owner delegates a phase
when its own model does not match that role. Task-specific choices override
these defaults; live discovery resolves provider instances and model IDs.
Unavailable required routing needs a user decision rather than silent substitution.

The [plan-driven slice loop](2026-10-05-plan-driven-slice-loop.md) retains its
delivery and authorization boundaries. Drive additionally retains behavioral
gate evidence and later questions in its external state directory. It checks
those records before dependency launches, cleanup and completion; delivery
status alone does not establish behavior. `own-change` and `drive` stay manual.

## Alternatives considered

- A fixed reproduction agent, implementation agent and review agent sequence
  adds handoffs even when one check suffices and does not fit every task.
- Extending diagnosis alone leaves feature, refactor and integration work
  without the same evidence and blocker contract.
- Treating limitations as completion avoids a question by making an unapproved
  decision about the user's required outcome.

## Consequences

Agents can coordinate more of the execution while the user retains decisions
about scope and unavailable proof. Read-only research and metadata edits keep
their narrower authority. Runnable evidence must survive until recipients can
use it; only meaningful production regression tests belong in commits.

Validation consists of skill-reference and metadata checks plus independent
scenario review. These are instruction changes, so no production regression
test or artificial red run is added. Home Manager activation is required to
update the installed skill and instruction copies.
