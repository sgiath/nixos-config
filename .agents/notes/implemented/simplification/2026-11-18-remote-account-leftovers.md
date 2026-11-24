# Agent Note: Remove the Remote account leftovers

Status: implemented

## Problem

The Remote account was retired on 2026-11-16 (`72278658`), leaving two temporary
cleanup hooks for hosts that might still hold Remote state:

- `fxProxy` in `modules/home/agents/cliproxy.nix` deleted the `cliproxy-remote`
  fx provider and model that agents hosts merged into `~/.fx/settings.json`
  between 2026-11-06 (`c1f4fda7`) and 2026-11-16.
- `SOURCES` in `modules/home/agents/archive/ship.py` still listed
  `.claude-remote`, `.codex-remote`, and `.config/remote-agents` so any
  unshipped files reached ClickHouse before the directories disappeared.

## Decision

Remove the retired Remote account leftovers:

- Drop `del(.providers["cliproxy-remote"], .models["cliproxy-remote"])` from
  `fxProxy` in `modules/home/agents/cliproxy.nix`.
- Remove `.claude-remote`, `.codex-remote`, and `.config/remote-agents` from
  `SOURCES` in `modules/home/agents/archive/ship.py`, and reduce the rollout
  tests in `modules/home/agents/archive/test_ship.py` to `.codex`.

## Alternatives considered

- **Keep the fx deletion permanently.** No-op once the key is gone, but leaves a
  reference to a retired account in the active config filter.
- **Replace `.providers` outright in `fxProxy`.** Avoids naming retired keys,
  but would also delete providers added by hand.

## Consequences

- `ceres` and `vesta` were verified to have no `cliproxy-remote` key in
  `~/.fx/settings.json`. `vesta` has none of the three Remote directories;
  `ceres` has no `~/.codex-remote` or `~/.config/remote-agents`, while
  `~/.claude-remote` exists (created 2026-11-19, holding only `.claude.json`,
  a changelog cache, a backup, and an empty `sessions/` directory with no
  transcripts).
- `pallas` last shipped to ClickHouse on 2026-11-23 (after `72278658`) with no
  Remote sources recorded, but was offline over Nebula when this cleanup ran;
  sgiath authorized dropping the leftovers after deploying across hosts. If an
  older backup or unswitched Pallas state still has `cliproxy-remote`, fx ignores
  it because `.provider` stays `cliproxy`. `ship.py --discover` flags remaining
  nested session JSONL files under those directories, but does not catch
  top-level `.claude-remote/history.jsonl`, `.codex-remote/history.jsonl`, 2025
  Codex `sessions/*.json`, or Grok `summary.json`.
