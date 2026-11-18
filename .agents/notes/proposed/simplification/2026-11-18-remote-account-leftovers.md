# Agent Note: Remove the Remote account leftovers after Pallas activates

Status: proposed

## Problem

The Remote account was retired on 2026-11-16 (`72278658`). Two pieces of code
remain only for hosts that may still hold Remote state:

- `fxProxy` in `modules/home/agents/cliproxy.nix` deletes the
  `cliproxy-remote` fx provider and model that every agents host merged into
  `~/.fx/settings.json` from 2026-11-06 (`c1f4fda7`) to 2026-11-16.
- `SOURCES` in `modules/home/agents/archive/ship.py` still ships
  `.claude-remote`, `.codex-remote` and `.config/remote-agents`, so whatever a
  host still has there reaches the archive before the directories go.

Checked 2026-11-18:

- Ceres and Vesta: no `cliproxy-remote` in `~/.fx/settings.json`, and none of
  the three directories exists.
- Pallas: offline (no SSH over Nebula or LAN). Its archived Claude
  transcripts run Claude Code 2.1.323, which Ceres first ran on 2026-11-13,
  and its last shipment was on 2026-11-15, so it runs a generation from inside
  the fx window and is expected to still have the entry. It has never shipped
  a Remote source, but `87676684` (2026-11-16) added Remote Grok sessions and
  archived or compressed Codex rollouts after that last shipment, so no rows
  do not prove there is nothing to ship.
- Juno1: never installed (sgiath, 2026-11-18).

`ship.py --discover` reports leftover session JSONL in these directories once
`SOURCES` drops them, but not `.claude-remote/history.jsonl`, the 2025 Codex
`sessions/*.json` files or Grok `summary.json`, so dropping the sources before
Pallas is checked could lose data silently.

## Proposal

Once Pallas has activated a generation since `72278658` and its hourly
shipper has run:

1. Confirm `grep -c cliproxy-remote ~/.fx/settings.json` prints `0` there,
   then remove the `del(...)` line from the `fxProxy` filter.
2. Confirm the Remote directories are gone from Pallas (or delete them after
   comparing their files with `archive.raw`), then remove the Remote entries
   from `SOURCES` and reduce the tests in `test_ship.py` that use
   `.codex-remote` as a second Codex home to `.codex`.

## Alternatives considered

- **Keep the fx deletion permanently.** It is a no-op once the key is gone,
  but it keeps a reference to a retired account in the filter.
- **Replace `.providers` with the overlay outright.** Removes stale providers
  without naming them, but also deletes providers added by hand.
- **Drop the sources now and rely on `--discover`.** It misses the file kinds
  listed above.

## Acceptance criteria

- Pallas has no `cliproxy-remote` in `~/.fx/settings.json` and no
  `.claude-remote`, `.codex-remote` or `.config/remote-agents` directory.
- `rg 'cliproxy-remote|claude-remote|codex-remote|remote-agents'
  modules/home/agents/cliproxy.nix modules/home/agents/archive` finds nothing.

## Risks

- A host restored from a backup taken before 2026-11-16 would bring the fx
  entry back; fx ignores it because `.provider` stays `cliproxy`.
