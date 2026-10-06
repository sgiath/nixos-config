# Plan format

A plan lives at `.agents/plans/<yyyy-mm-dd>-<topic>/` in the repository that holds most of the work. `scripts/plan-status` parses only the frontmatter: flat `key: value` lines, lists as `[a, b]`, no nesting.

## `plan.md`

```markdown
---
topic: support-inbox
repos: [CrazyEggInc/ce, CrazyEggInc/db-schemas]
parallel: 1
order: [01, 02, 03, 05, 04]
deploy_check: "<command that exits 0 when {sha} runs in production>"
---

# Plan: <title>

## Goal

<one paragraph: what is true when every slice is done>

## Spec

- [<note title>](../../notes/proposed/<class>/<yyyy-mm-dd>-<topic>.md)

## Standing rules

- <rules every worker follows, e.g. "verify with read-only production data">
```

| Key | Default | Meaning |
| --- | --- | --- |
| `topic` | required | Short kebab-case name; used in branch names and thread titles. |
| `branch_prefix` | `<topic>/` | Slice branch is `<branch_prefix><NN>-<slug>` in every repository. |
| `repos` | the plan repository | GitHub `owner/name` of every repository a slice may open PRs in. |
| `parallel` | `1` | Slices in progress or review at once. A slice with `migration: true` never runs beside another slice. |
| `order` | numeric order | Delivery order by slice id. Slices not listed run after the listed ones. |
| `deploy_check` | none | Shell command run from the repository root with `{sha}` replaced by the merge commit of the slice's PR in the plan repository. Exit 0 means that commit runs in production. Without it the user reports deploys. |

## `NN-<slug>.md`

```markdown
---
title: Admin Oban instance
blocked_by: [01]
deploy_gate: true
migration: true
---

## Deliverable

<what ships in this slice, as observable behavior>

## Acceptance gate

<how a reviewer proves it works: the scenario, data and evidence required>

## Questions before starting

1. <decision the worker must not guess>

## Stop boundary

<what is explicitly left for later slices>
```

| Key | Default | Meaning |
| --- | --- | --- |
| `title` | slug | Human title, used in thread titles and messages. |
| `blocked_by` | `[]` | Slice ids that must be done (merged, and deployed when they are deploy-gated) first. |
| `deploy_gate` | `true` | `false` when dependants only need the slice merged. |
| `migration` | `false` | `true` for any schema change; serializes the slice. |

The slice's own PR records the user's answers under "Questions before starting" and moves any resulting decision into the spec note. Nothing else records progress in the plan; `plan-status` derives it.
