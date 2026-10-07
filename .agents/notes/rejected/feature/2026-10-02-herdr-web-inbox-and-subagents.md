# Agent Note: herdr web UI inbox hygiene and OMP subagent transcripts

Status: rejected - herdr web UI removed; T3 Code remains configured

## Problem

[herdr web UI on every host](../../archived/feature/2026-10-02-herdr-web-ui-everywhere.md)
gives one sidebar and push alerts for every herdr pane, but two parts of the
"threads are an inbox" workflow are missing upstream:

- Settling: the UI shows pane status but has no archive flow. Finished panes
  stay in the sidebar until they are closed by hand, so the "Needs you" list
  is the only view that stays short.
- OMP subagents: the chat view reads only the parent `.jsonl` that herdr
  reports. OMP writes subagent logs into the sibling `<session>/` directory,
  so subagents show only as task tool rows with their final results.

Neither belongs in this flake; both change herdr-web-ui itself.

## Proposal

Track both as herdr-web-ui pull requests, or as a custom herdr plugin if
upstream declines:

1. Settling: auto-close panes idle for more than 7 days, and close a thread
   when its pull request merges.
2. Subagent transcripts: let the chat view open a task row's subagent log
   from `<session>/` beside the parent `.jsonl`.

## Alternatives considered

- **Local patches in `packages/herdr-web-ui`**: upstream releases nearly
  daily, so patches would need rebasing on almost every bump.
- **A cron job that closes idle panes with `herdr pane close`**: covers
  settling without upstream, but cannot tell a finished thread from one
  waiting on a long build, and does nothing for transcripts.

## Acceptance criteria

- A thread whose pull request merged, or that has been idle for more than
  7 days, leaves the sidebar without manual action.
- Opening an OMP task row in chat view shows that subagent's transcript.

## Risks

- Upstream may reject OMP-specific transcript handling; a custom plugin then
  has to follow herdr-web-ui's protocol changes.
- Auto-closing a pane kills whatever still runs in it.
