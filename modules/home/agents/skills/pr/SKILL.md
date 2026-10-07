---
name: pr
description: "Draft, create or update a pull request, including its title, body, repository requirements and T3 registration. Does not monitor CI or merge."
---

# Create or update a PR

Own PR publication and description updates. Read skill://write-as-sgiath before composing text in the user's name.
Use the project's domain language from `CONTEXT.md` when present. CI and review follow-up belong to
skill://babysit-pr; this skill does not start babysitting automatically.
Honor the requested operation: a draft-only request produces text without publishing or changing a host PR.

## Repository requirements

Before creating or updating a PR, read applicable repository steering and inspect available project-local skills
for PR requirements. Load the relevant policy alongside this workflow. Repository policy supplies labels,
dependencies, review conventions and checks; this skill owns publication. A policy must not call this skill again.
Do this for each repository in a companion PR set.

The repository's PR template controls headings, marker lines, checklists and terminology. Use its default template
unless the user selects another. When no template exists, use Summary, Evidence, Merge Danger and Links as needed.
Do not inject a second set of risk fields into a template that already defines them.

## Establish the operation

- Resolve repository, authenticated user, verified remote, head repository/branch and intended base. Preserve
  unrelated work. Do not assume `origin`, `main`/`master`, or that a supplied PR belongs to this checkout.
- For creation, inspect the branch, working tree, actual diff and commits. Find an open PR for the exact head
  repository/branch and reuse it. Distinguish an empty lookup from an authentication/network failure; check again
  immediately before creating. Do not silently revive a closed or merged PR.
- For a body/title update on an existing PR, read its current description, diff and head. Update only the requested
  metadata; this operation does not require committing, pushing or changing its draft status.
- Preserve authorization from the invoking workflow. If committing/pushing is already authorized, complete that
  work without asking again; read skill://conventional-commit when committing. Otherwise ask only if publication
  depends on an unapproved commit or push. Never include unrelated work. Account for intentionally uncommitted files.

## Write the title and body

Lead with the concrete problem and resulting behavior. Ground the title, motivation, links and risk in the final
diff and task context. Rewrite the description when later fixes change its scope.

- **Summary:** one or two sentences. When useful, add the smallest visual from [show-me](../show-me/SKILL.md):
  pseudocode, call tree, component/file tree, Mermaid, or a focused diff. Skip its HTML-file option.
- **Evidence:** gather runtime proof before writing. For a visual change, use before/after screenshots when the
  environment supports them. For behavior, name the failing-before/passing-after test or command and what it proves.
  For a refactor, cite existing tests or comparison output. State verification limits; never invent test runs or
  manual testing. Existing evidence supplied by the user or invoking workflow is usable.
- **Merge Danger:** follow the template's terms. Without a template, describe **Reversible** (whether reverting
  undoes the change, naming migrations, data changes, external side effects or deploy ordering) and **Impact** (who
  or what can break). Apply label values only when repository policy defines them.
- **Links:** include supported ticket links and companion PR dependencies with their safe merge order.

## Publish or update

Use the available host API or CLI. With `gh`, write the exact multiline body to a temporary file and pass
`--body-file`; use explicit repository, base and head when creating. Set the authenticated user as assignee and
all repository-required labels at creation. Resolve unmerged schema dependencies before publishing.

For creation, finish authorized task commits and push the intended branch explicitly to the verified remote with
upstream tracking. Confirm the remote head contains the intended commits before opening the PR. Never push task
changes to the base branch accidentally. Description-only updates do not require a push.

Create a non-draft PR when implementation is complete unless the user requested a draft. Mark an existing draft
ready only when readiness is part of the task. Check for duplicates again after an ambiguous creation failure
before retrying. An API error is not evidence that no PR was created.

For an existing PR, preserve unrelated body content and metadata. Apply repository-specific token-scope fallbacks
without broadening credentials. Verify the resulting URL, head/base, description and required labels.

## T3 registration and delivery

When T3 exposes `link_pull_request`, link the full URL immediately after creation or before working on an existing
PR. Link every companion/stack layer this task owns. Before finishing, use `list_thread_pull_requests` and register
any missing task PRs. Report linking failures; host API/CLI operations alone do not register a PR with T3.

For draft-only work, return the requested title/body. Otherwise return the PR URL(s), a concise summary,
verification limits and dependency order. Publication is not proof of
merge readiness. Do not merge, enable auto-merge, deploy or start monitoring unless separately authorized.
