## Git

- Safe by default: git status/diff/log.
- Destructive ops forbidden unless explicit (reset --hard, clean, restore, rm, …).

## Shortcut

- we use Shortcut for ticket management in CrazyEgg and you have Shortcut MCP available to you
- when user mentions ticket he probably means Shortcut, use the MCP to pull the relevant context from the ticket
- do not update tickets tickets or add comments or respond directly, always ask user permission to post a comment, since it will be done by their name

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
