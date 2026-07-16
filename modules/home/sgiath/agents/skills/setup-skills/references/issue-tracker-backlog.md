# Issue tracker: Backlog.md

Issues and PRDs for this repo live in Backlog.md. Use the Backlog MCP tools for all operations; do not edit Backlog markdown files directly.

## Conventions

- **Read workflow guidance**: use `get_backlog_instructions` or the Backlog MCP resources when creating, executing, or finalizing tasks.
- **Create an issue**: `task_create` with `title`, `description`, `status`, `priority`, `labels`, `assignee`, `acceptanceCriteria`, and optional `parentTaskId` or `dependencies`.
- **Create a PRD**: use `document_create` for long-lived product/specification docs. If implementation work is needed, create a linked task with `task_create` and add the document path or URL to `documentation`.
- **Read an issue**: `task_view` with the Backlog task ID.
- **List issues**: `task_list` with appropriate `status`, `assignee`, `milestone`, `labels`, or `search` filters. Use `task_search` for broader title/description/file-path search.
- **Comment on an issue**: `task_edit` with `commentsAppend` and optional `commentAuthor`. Comment bodies may contain Markdown, but standalone `---` lines are reserved as comment delimiters.
- **Apply / remove labels**: `task_edit` with the complete desired `labels` array.
- **Assign / unassign**: `task_edit` with the complete desired `assignee` array.
- **Close**: `task_edit` with `status: "done"` and a `finalSummary` or `finalSummaryAppend` entry. Do not call `task_complete` immediately; it is for periodic cleanup of already-done tasks.

Backlog task IDs are the canonical identifiers. Prefer task IDs over file paths in human-facing instructions.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs are represented as Backlog tasks:

- **Create a request from a PR**: `task_create` with the PR title/body summarized in `description`, `references` containing the PR URL, and labels such as `triage` or `external-pr`.
- **Read a PR request**: `task_view` for the Backlog task. Use entries in `references` as context pointers.
- **Comment / label / close the request**: use `task_edit` with `commentsAppend`, `labels`, and `status`.

Bare `#42` references are not Backlog task IDs. Ask for the Backlog task ID or search with `task_search` when only a title, description, file path, or external URL is known.

## When a skill says "publish to the issue tracker"

Create a Backlog task with `task_create`.

## When a skill says "fetch the relevant ticket"

Run `task_view` with the Backlog task ID. If the user provides partial context, search first with `task_search` or `task_list`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single Backlog task with **child** tasks as tickets.

- **Map**: a single task labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog in `description`, `notesSet`, or `planSet`. Create it with `task_create`.
- **Child ticket**: create a task with `parentTaskId` set to the map task ID. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, assign the ticket to the driving dev.
- **Blocking**: Backlog task dependencies are canonical. Add blockers with `task_edit` on the child using `dependencies: ["task-id", "task-id"]`. A ticket is unblocked when every dependency is `done`.
- **Frontier query**: list the map's open children with `task_list` or `task_search`, scoped by the map task ID or `wayfinder:<type>` labels. For each candidate, read it with `task_view`; drop any with an open dependency or an assignee. First in map order wins.
- **Claim**: `task_edit` with `id` and `assignee` set to the driving dev - the session's first write.
- **Resolve**: `task_edit` on the child with `commentsAppend` for the answer, `status: "done"`, and `finalSummary`; then append a context pointer to the map's Decisions-so-far using `task_edit` on the map.
