---
name: shortcut-ticket-context
description: Use when the user pastes a Shortcut ticket or story link, a Shortcut URL, an sc-XXXXX id, or a \#XXXXX ticket reference.
---

# Shortcut Ticket Context

## Goal

Load ticket context before answering. Shortcut is the company collaboration hub — a **context source**, not a work tracker for agents. This skill is strictly read-only: never create, update, or comment on Shortcut stories.

## Steps

1. Use Shortcut MCP to find the referenced ticket or story.
2. Prefer `shortcut_stories-get-by-id` with `full: true`.
3. If needed, read history and comments with read-only Shortcut tools.
4. Ask the user if he wants to implement the ticket or add more context for the task

## Hand-off

If the work needs granular tracking (breakdown into slices, blocking edges, agent progress), that happens on the configured issue tracker (usually Linear) via `/to-tickets` — with each Linear ticket linking back to the Shortcut story URL. Do not mirror or write the breakdown into Shortcut.

## Matching Inputs

- Pasted Shortcut ticket or story links
- Shortcut URLs
- `sc-XXXXX`
- `#XXXXX`
