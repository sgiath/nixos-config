---
name: pr
description: "Use when writing or updating a pull request body."
---

# PR body

Write the body for fast human review: what changed, proof that it works, and how risky the merge is. Skip preambles and keep prose brief. Use the project's domain language from `CONTEXT.md` when it exists. The body is authored in the user's name, so also read skill://write-as-sgiath for the prose.

```markdown
## Summary

<one or two sentences, then the smallest visual that makes the change clear>

## Evidence

- **Before:** <screenshot, output, or failing test run>
  **After:** <screenshot, output, or passing test run>

## Merge Danger

**Door:** <one-way or two-way>

<optional: why>

**Blast radius:** <one or two words>

<optional: what could break and for whom>
```

When the repository has a PR template, keep its headings, marker lines, and checklists, and put this content into the matching sections. Add **Evidence** or **Merge Danger** as their own sections when the template has no place for them. Link the ticket where the template or repository expects it.

## Summary

Pick the smallest view from the menu in [show-me](../show-me/SKILL.md): pseudocode, call tree, component tree, file tree, Mermaid, or a focused `diff` of the changed shape. Skip its HTML-file option. One visual is usually enough; never use every format. Keep only the calls, files, and states a reviewer needs.

## Evidence

Show that the change works at runtime, not that the code reads correctly. Gathering evidence often means running one more test or taking one more screenshot; do it before writing the body.

- Visual change: before/after screenshots, when the environment can produce them.
- Behavior change: the test that failed before and passes after, named and summarized as pseudocode of its steps, or the command output before and after.
- Refactor with no behavior change: the existing tests or comparison output that prove the behavior is unchanged.

Report only checks that actually ran. If something could not be verified (production-only path, missing credentials), say so here instead of implying coverage.

## Merge Danger

A two-way door can be walked back by reverting the PR. A one-way door cannot be cheaply undone: data migrations or deletions, external side effects, published APIs or messages, irreversible configuration. Name the reason when it is one-way.

Blast radius is who or what can break if the change is wrong: one internal page, a background job, all customers' tracking script, a consumer of a shared API, mobile layout. Small two-way changes need light review; state the radius honestly so the reviewer can calibrate.
