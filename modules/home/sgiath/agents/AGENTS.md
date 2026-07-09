## Git

- Safe by default: git status/diff/log.
- Destructive ops forbidden unless explicit (reset --hard, clean, restore, rm, …).

## Issue tracking: Shortcut vs Linear

Two trackers with different roles — do not confuse them:

- **Shortcut** = company collaboration hub (CrazyEgg). Human-facing; groups context and resources for a task, not granular progress tracking. **Read-only for you**: pull context via Shortcut MCP freely, but never create/update stories or post comments without explicit user permission (writes appear under the user's name).
- **Linear** = the user's personal tracker; only the user and agents have access. This is the **work surface**: granular tickets, blocking edges, agent progress. When skills say "issue tracker" or "publish tickets", they mean Linear (or the repo's configured tracker) — never Shortcut. You may create/update Linear issues freely.

Disambiguating "ticket":

- `sc-XXXXX`, Shortcut URL, or "story" → Shortcut (load context via MCP)
- `TEAM-123` style id or Linear URL → Linear
- Bare "ticket" while discussing company work context → probably Shortcut; while tracking/breaking down agent work → Linear. If genuinely ambiguous, ask.

Typical flow: a Shortcut story is *input*; its granular breakdown lives in Linear. Linear issues derived from a Shortcut story should link back to the story URL — but Linear tickets with no Shortcut counterpart are normal too.

## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.
- Break down work into small, iterable, testable chunks

## Writing code

- Keep files under ~500 lines of code; split/refactor as needed
- Always strive for concise, simple solutions
- If a problem can be solved in a simpler way, propose it
- If asked to do too much work at once, stop and state that clearly
- when implementing bug fix or new functionality, prefer using test-driven development approach

## Debug Logging

Features must log errors, unexpected exceptions, and operational issues with enough context to debug failures. Long-running jobs must also log start, progress checkpoints, and completion so a stuck run can be diagnosed from logs.

## Getting help

**Ask, Don't Assume**: Always ask for clarification rather than making assumptions. If you're stuck or struggling, stop and ask for help

## Critical Thinking

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
