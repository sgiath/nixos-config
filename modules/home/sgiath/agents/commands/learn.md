---
description: Extract non-obvious learnings from session into agent knowledge base
---

Analyze this session and extract non-obvious learnings.

## Where to Put Learnings

Check the root AGENTS.md for references to other documents (workflows, overviews, etc.). Learnings may belong in:

- **AGENTS.md** (root or nested) → general guidance, patterns, constraints
- **Other referenced docs** → whatever AGENTS.md points to

Place learnings at appropriate scope:
- Global → root AGENTS.md or global config
- Project-specific → project's AGENTS.md
- Feature/module-specific → nested AGENTS.md near relevant code

## What Counts as a Learning

Non-obvious discoveries only:
- Hidden relationships between components
- Execution paths that differ from how code appears
- Non-obvious config, env vars, flags
- Debugging breakthroughs (misleading errors, actual root causes)
- API/tool quirks and workarounds
- Commands not documented elsewhere
- Architectural decisions and constraints
- Files that must change together

## What NOT to Include

- Obvious/documented facts
- Standard language/framework behavior
- Already captured knowledge
- Verbose explanations
- Session-specific details

## Process

1. Review session for discoveries, multi-attempt fixes, unexpected connections
2. Determine scope and destination (AGENTS.md vs command vs skill vs other)
3. Read existing file at target location
4. Update or create as needed
5. Keep entries concise (1-3 lines per insight)

Summarize: which files updated/created, how many learnings each.

$ARGUMENTS
