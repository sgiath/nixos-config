---
name: write-plan
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write implementation plans that describe **what must be true**, not **how to code it**.

The plan should give an implementing agent enough context to make good local engineering decisions without turning the plan into pseudo-implementation. Do not prescribe test-first, tracer-bullet, commit cadence, exact function bodies, or other implementation procedure unless the user explicitly requested that constraint.

Assume the implementing agent is a skilled developer who will inspect the codebase, choose the right implementation technique, and decide the execution order inside each chunk.

**Announce at start:** "I'm using the write-plan skill to create the implementation plan."

**Save plans to:** `docs/plans/filip/YYYY-MM-DD-<feature-name>.md`

- User preferences for plan location override this default.

## Scope Check

If the spec covers multiple independent subsystems, suggest separate plans. Each plan should produce working, testable software on its own.

If the requested scope is too large for a useful implementation plan, stop and ask for a narrower slice.

## Planning Principles

- Focus on behavior, boundaries, data flow, user-visible outcomes, failure modes, and acceptance criteria.
- Split work into atomic, independently reviewable, testable chunks.
- Explain how chunks relate to each other: dependencies, ordering constraints, shared contracts, and integration points.
- Identify relevant files, modules, APIs, commands, services, or documents as orientation, not as mandatory edit instructions.
- Avoid code examples unless the user specifically asks for them or a tiny interface sketch is necessary to remove ambiguity.
- Avoid exact implementation steps such as "write a failing test", "add this function", "run this command", or "commit".
- Leave implementation workflow choices to the implementing agent.
- Prefer concise plans. Remove anything that does not reduce implementation risk.

## Context Gathering

Before writing tasks, inspect enough of the repo to understand:

- Existing domain language and naming.
- Current module boundaries and ownership.
- Nearby tests and verification patterns.
- Existing documentation or ADRs that should be updated.
- Security-sensitive surfaces such as auth, secrets, network input, file access, permissions, logging, and dependency boundaries.

Do not lock in a file-by-file implementation map unless the codebase makes that map obvious. When uncertain, name likely areas to inspect instead of dictating exact files.

## Plan Document Header

Every plan must start with this header:

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** implement this plan task-by-task. Tasks use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing the outcome]

**Behavior:** [2-4 sentences describing user/system behavior after completion]

**Primary Surfaces:** [Modules, workflows, commands, APIs, UI screens, services, or docs involved]

---
```

## Task Structure

Each task should describe an atomic outcome, not a coding recipe.

```markdown
### Task N: [Outcome Name]

**Outcome:** [What new behavior, contract, or state exists after this task]

**Scope:** [What is included; explicitly note important exclusions]

**Touches:** [Likely modules/files/APIs/docs to inspect or update, if known]

**Dependencies:** [Earlier tasks, external inputs, or "None"]

**Behavior:**

- [Observable behavior or contract]
- [Important edge case, failure mode, or integration behavior]
- [Interaction with other chunks]

**Acceptance checks:**

- [ ] [Concrete check an implementer or reviewer can verify]
- [ ] [Concrete check covering relevant tests, logs, docs, UI behavior, or command behavior]

**Notes:** [Optional constraints, tradeoffs, or decisions already made]
```

## Required Final Tasks

The second-to-last task must be a security review.

Security review should cover the surfaces touched by the plan and include acceptance checks for relevant risks, such as:

- Authentication and authorization boundaries.
- Secrets, credentials, tokens, and sensitive configuration.
- Input validation, parsing, injection, path traversal, and unsafe deserialization.
- Network calls, external services, dependency trust, and supply-chain risk.
- Logging of sensitive data and enough context for operational debugging.
- File permissions, process execution, sandbox boundaries, and privilege changes.

The last task must be documentation of decisions made during planning and implementation.

Documentation should live as close to the code as practical:

- Use code-adjacent documentation first: module docs, moduledoc for Elixir, docstrings, type docs, comments for non-obvious invariants, examples, or README sections near the feature.
- Use `docs/` markdown when the decision spans multiple modules, workflows, services, or operational processes.
- Document final decisions, rejected alternatives when meaningful, operational notes, and security or compatibility implications.

## No Pseudo-Implementation

These are plan failures:

- Large code blocks or pseudo-code that effectively implements the feature.
- Exact function bodies, class definitions, queries, migrations, config snippets, or test bodies unless explicitly requested.
- Prescribing TDD, tracer bullets, commit frequency, or subagent strategy.
- Step-by-step implementation procedure inside tasks.
- Vague placeholders such as "TBD", "TODO", "handle edge cases", or "add appropriate validation".
- Tasks that cannot be tested or reviewed independently.
- Tasks with no clear relationship to the feature goal.

## Self-Review

Before saving the plan, review it against this checklist and fix issues inline:

1. **What over how:** Does each task describe behavior and acceptance, not implementation mechanics?
2. **Atomic chunks:** Can each task be implemented, tested, and reviewed independently?
3. **Relationships:** Are dependencies and interactions between tasks clear?
4. **Coverage:** Does every important requirement from the spec map to a task?
5. **Verification:** Are acceptance checks concrete without dictating the implementer's workflow?
6. **Security:** Is security review present as the second-to-last task?
7. **Documentation:** Is documentation of decisions present as the final task, with code-adjacent docs preferred?
8. **No placeholders:** Remove vague placeholders and pseudo-implementation.
