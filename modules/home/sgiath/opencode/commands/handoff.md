---
description: Create GitHub issue(s) from planning session
---

# Handoff: Create GitHub Issue(s)

Create GitHub issue(s) capturing the current planning/discussion for future work.

## Step 1: Gather Context

Extract from conversation:
- **Goal**: What problem/feature was discussed
- **Approach**: Agreed implementation strategy
- **Tasks**: Action items, todos, refactoring list
- **Context**: Key files, modules, functions involved
- **Constraints**: Edge cases, gotchas, dependencies
- **Open questions**: Unresolved decisions

## Step 2: Assess Scope

Count distinct work items. If **3+ independent tasks** that could be worked separately:

Ask user:
```
Found [N] distinct work items:
1. [brief description]
2. [brief description]
...

Options:
A) Single issue (all items as checklist)
B) Multiple issues (one per item, linked)
C) Epic + sub-issues

Which approach?
```

If scope is small (1-2 related items) → proceed with single issue.

## Step 3: Get Repository Info

!`gh repo view --json nameWithOwner,url --jq '"\(.nameWithOwner) - \(.url)"'`

## Step 4: Create Issue(s)

### Single Issue Format

```bash
gh issue create \
  --title "[type]: [concise goal]" \
  --body "$(cat <<'EOF'
## Context

[Why this work matters / problem being solved]

## Approach

[Agreed strategy from planning session]

## Tasks

- [ ] [task 1]
- [ ] [task 2]
- [ ] ...

## Key Files

- `path/to/file.ts` - [why relevant]
- `path/to/other.ts` - [why relevant]

## Notes

[Constraints, edge cases, gotchas, dependencies]

## Open Questions

- [Any unresolved decisions]

---
*Generated from planning session*
EOF
)"
```

### Multiple Issues Format

For each work item:
```bash
gh issue create \
  --title "[type]: [specific task]" \
  --body "$(cat <<'EOF'
## Context

[Brief context for this specific task]

## Tasks

- [ ] [subtask 1]
- [ ] [subtask 2]

## Related

- Part of: [link to epic or parent issue if exists]
- Depends on: [link to blocking issues if any]
- Blocks: [link to dependent issues if any]

## Key Files

- `path/to/file.ts`

---
*Generated from planning session*
EOF
)"
```

## Step 5: Report Results

Output:
```
Created [N] issue(s):
- #123: [title] - [url]
- #124: [title] - [url]

Ready for future work session.
```

## Issue Title Prefixes

Use appropriate prefix:
- `feat:` - New functionality
- `fix:` - Bug fix
- `refactor:` - Code improvement, no behavior change
- `docs:` - Documentation
- `perf:` - Performance improvement
- `test:` - Test additions/fixes
- `chore:` - Maintenance, deps, config

## Rules

- **Include file paths** - Makes future context-gathering fast
- **Be specific** - Vague issues waste future time
- **Link related issues** - Use `#number` references
- **Add labels** if obvious (skip if unsure)
- **Don't over-scope** - Better to have focused issues
