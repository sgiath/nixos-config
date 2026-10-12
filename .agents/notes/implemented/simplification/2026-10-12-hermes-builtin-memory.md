# Agent Note: Hermes uses built-in memory only

Status: implemented

## Problem

Hermes v0.21 moved the Holographic memory provider out of core into a catalog plugin. With `memory.provider = "holographic"`, agent initialization attempts to install that plugin into `HERMES_HOME/plugins` (with retries limited after a failure); on the Nix-packaged agent the install fails looking for `uv.lock` inside the read-only store environment. Hermes then runs with built-in memory only while still reporting Holographic as configured and its plugin as missing.

The Holographic store on Vesta held 27 facts (about 6 KB) written by `auto_extract` between April and October 2026. None had a recorded retrieval or a trust change from the default.

## Decision

`modules/nixos/services/hermes-agent.nix` sets `memory.provider = ""`, the value `hermes memory off` writes and one of the core sentinels in `agent/memory_provider.py`. The upstream activation step deep-merges Nix settings into the runtime `config.yaml` and never deletes keys, so the provider has to be overridden explicitly; removing the line would leave `holographic` in place.

Built-in memory stays on (`memory_enabled`, `user_profile_enabled`) and its caps are doubled to `memory_char_limit = 4400` and `user_char_limit = 2750`, about 1,600 and 1,000 tokens. Both files were at 94% and 98% of the default caps before any Holographic fact is folded in. The caps stay bounded: the 27 facts alone exceed the added room, so only facts still worth injecting every turn move into the files, and the rest stay in the archive. Past conversations remain reachable through `session_search` over `state.db`.

## Alternatives considered

- **Install the Holographic catalog plugin through Nix.** Restores a local FTS5/HRR store with no services, but adds packaging for a store that recorded no retrievals, and repeats when the catalog pin moves.
- **Mnemosyne.** Local SQLite with vector and FTS search, but needs an embedding model and extra Python dependencies in the agent environment.
- **Honcho, Hindsight, Mem0, Supermemory.** Each needs an external API or a server stack (Hindsight needs Postgres). Not justified for one user's preferences and project facts.
- **Keep the default caps.** Costs no prompt tokens, but both files were nearly full, so larger new entries would require consolidation.

## Consequences

- No external memory provider is activated, and `hermes memory status` reports built-in only.
- The prompt grows by up to about 1,300 tokens when both files fill the new caps; the snapshot is frozen per session, so it stays in the prompt cache.
- The runtime `config.yaml` keeps an inert `plugins.hermes-memory-store` block; only the Holographic provider reads it.
- `HERMES_HOME/memory_store.db` is kept untouched. Its facts, with their metadata, are exported to a readable Markdown archive under `HERMES_HOME` on Vesta (outside the repository and store), and a short `MEMORY.md` entry points the agent to it. Re-adding an external provider should start from the archive, not from `auto_extract` again.

## Verification

The live gateway journal reproduced the missing `uv.lock` migration failure, and a throwaway check of the production `_init_memory` path failed before the configuration change because it requested provider recovery. The unchanged check passed afterward and verified a memory write survives reinitialization. The full Vesta NixOS system build passed. On Vesta, a fresh Matrix memory initialization uses the configured limits, includes the archive pointer in its prompt snapshot and emits no provider warning; `hermes memory status` shows built-in only. The 27 exported records round-trip with their metadata, the original database stays byte-identical through migration, and the captured Iris conversation remains searchable after restart.
