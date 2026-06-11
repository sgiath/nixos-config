## Git

- Safe by default: git status/diff/log.
- Destructive ops forbidden unless explicit (reset --hard, clean, restore, rm, …).

## Task, tickets, backlog

- whenever user mentions task, ticket or issue he means Backlog.md task unless explicitely said otherwise. You can get its content through MCP and if it is not available, through command `backlog task show <task-id> --plain`
- when working with Backlog.md tasks you should use all the available structured fields as much as possible to preserve the intent. If you are unsure what is available you can always run `backlog task edit --help` to get a comprehensive list of options you can use

## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.
- Break down work into small, iterable, testable chunks

## Writing code

- Keep files under ~500 lines of code; split/refactor as needed
- Always strive for concise, simple solutions
- If a problem can be solved in a simpler way, propose it
- If asked to do too much work at once, stop and state that clearly

## Debug Logging

Features must log errors, unexpected exceptions, and operational issues with enough context to debug failures. Long-running jobs must also log start, progress checkpoints, and completion so a stuck run can be diagnosed from logs.

## Getting help

**Ask, Don't Assume**: Always ask for clarification rather than making assumptions. If you're stuck or struggling, stop and ask for help

## Critical Thinking

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
