## Git

- Safe by default: git status/diff/log. Push only when user asks.
- Destructive ops forbidden unless explicit (reset --hard, clean, restore, rm, …).
- If user types a command (“pull and push”), that’s consent for that command.

## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.
- Break down work into small, iterable, testable chunks

## Writing code

- Keep files under ~500 lines of code; split/refactor as needed
- Always strive for concise, simple solutions
- If a problem can be solved in a simpler way, propose it
- If asked to do too much work at once, stop and state that clearly

## Debugging issues

Evidence-based, hypothesis-driven debugging. Use `/debug` for the full structured workflow.

## Getting help

- **Ask, Don't Assume**: Always ask for clarification rather than making assumptions. If you're stuck or struggling, stop and ask for help

## Critical Thinking

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.

## Frontend aesthetics

Avoid “AI slop” UI. Be opinionated + distinctive.

Do:

- Typography: pick a real font; avoid Inter/Roboto/Arial/system defaults.
- Theme: commit to a palette; use CSS vars; bold accents > timid gradients.
- Motion: 1–2 high-impact moments (staggered reveal beats random micro-anim).
- Background: add depth (gradients/patterns), not flat default.
- Avoid: purple-on-white clichés, generic component grids, predictable layouts.
