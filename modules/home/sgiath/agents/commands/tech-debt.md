---
description: Scan codebase for tech debt, bugs, dead code, and refactoring opportunities
---

# Tech Debt Analysis: $ARGUMENTS

Systematically scan the codebase for technical debt and improvement opportunities.

## Scope

- **If `$ARGUMENTS` empty** → scan entire codebase
- **If `$ARGUMENTS` provided** → focus on specified path, module, or feature

## Step 1: Determine Scan Targets

If full codebase:
1. Identify major directories/modules (src, lib, app, etc.)
2. Note the primary language(s) and frameworks

If targeted:
1. Verify the path/module exists
2. Identify related files and dependencies

## Step 2: Parallel Exploration

**CRITICAL**: Spawn multiple `explore` agents in parallel to maximize speed. Each agent focuses on ONE concern:

```
Agent 1: POTENTIAL BUGS
- Null/undefined handling gaps
- Error handling inconsistencies  
- Race conditions
- Unvalidated inputs
- Edge cases not handled

Agent 2: DEAD CODE
- Unused exports/functions
- Unreachable branches
- Commented-out code blocks
- Deprecated code still present
- Unused imports/dependencies

Agent 3: COMPLEXITY
- Functions >50 lines
- Deep nesting (>3 levels)
- High cyclomatic complexity
- God objects/classes
- Long parameter lists (>4 params)

Agent 4: REFACTORING OPPORTUNITIES  
- Code duplication
- Inconsistent patterns
- Magic numbers/strings
- Missing abstractions
- Type safety gaps (any, unknown abuse)

Agent 5: ARCHITECTURE CONCERNS
- Circular dependencies
- Layer violations
- Tight coupling
- Missing interfaces/contracts
- Inconsistent module boundaries
```

For targeted scans, adjust agent count based on scope size.

## Step 3: Collect & Deduplicate

Gather results from all agents:
- Remove duplicates (same issue found by multiple agents)
- Group related issues
- Prioritize by impact

## Step 4: Generate Report

For each issue, provide:

```markdown
### [CATEGORY] Issue Title

**Location**: `path/to/file.ts:42-58`

**Current State**: 
Brief description of current code behavior

**Problem**:
Why this is problematic (bugs it could cause, maintenance burden, etc.)

**Suggested Change**:
Concrete proposal for improvement

**Priority**: HIGH | MEDIUM | LOW
```

## Output Format

```markdown
# Tech Debt Report: [scope]

**Scanned**: [date]  
**Scope**: [full codebase | specific path]  
**Issues Found**: [count]

## Summary by Category

| Category | Count | High | Med | Low |
|----------|-------|------|-----|-----|
| Bugs     | X     | X    | X   | X   |
| Dead Code| X     | X    | X   | X   |
| Complexity| X    | X    | X   | X   |
| Refactor | X     | X    | X   | X   |
| Architecture | X | X    | X   | X   |

## High Priority Issues

[List HIGH priority items first]

## Medium Priority Issues

[List MEDIUM priority items]

## Low Priority Issues  

[List LOW priority items]

## Quick Wins

[Issues that are easy to fix with high impact]

## Recommended Next Steps

1. [Actionable item]
2. [Actionable item]
3. [Actionable item]
```

## Priority Guidelines

**HIGH**:
- Active bugs or data corruption risks
- Security concerns
- Blocks other improvements
- Causes frequent developer friction

**MEDIUM**:
- Code smell but working
- Moderate maintenance burden
- Would improve testability
- Inconsistencies causing confusion

**LOW**:
- Style/preference issues
- Minor cleanup
- Nice-to-have improvements
- Theoretical problems

## Rules

- **BE SPECIFIC** - Include exact file paths and line numbers
- **BE ACTIONABLE** - Vague "refactor this" isn't helpful
- **EXPLAIN WHY** - Not just what, but why it matters
- **PARALLELIZE** - Always spawn explore agents concurrently
- **DON'T BIKESHED** - Skip style nitpicks unless egregious
- **CONSIDER CONTEXT** - Not all tech debt needs fixing now
