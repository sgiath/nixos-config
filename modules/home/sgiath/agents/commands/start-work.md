---
description: Exit exploration and start implementing
agent: build
model: openai/gpt-5.3-codex
---

Transition from exploration to implementation. Switch to the **build** agent and begin coding what was discussed.

## What to do

1. **Summarize the exploration** - Brief recap of what was agreed:
   - The problem/feature being addressed
   - The approach chosen
   - Key constraints or edge cases identified
   - Any open questions that remain

2. **Switch to build agent** - Hand off to implementation mode

3. **Begin implementation** - The build agent should:
   - Use the exploration context to guide implementation
   - Follow tracer bullet approach (tiny end-to-end slice first)
   - Ask if anything is unclear before diving in

## Output format

```
## Exploration Summary

**Goal**: [what we're building/fixing]

**Approach**: [how we decided to do it]

**Key decisions**:
- ...

**Edge cases to handle**:
- ...

**Open questions** (if any):
- ...

---

Switching to build agent. Starting implementation...
```

## Notes

- This command is typically used after `/explore` sessions
- If the exploration didn't reach a clear conclusion, ask for clarification before proceeding
- The build agent inherits full conversation context
