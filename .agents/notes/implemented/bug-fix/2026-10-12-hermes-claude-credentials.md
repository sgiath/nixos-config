# Agent Note: Hermes service borrows the account's Claude Code login

Status: implemented

## Problem

The Vesta gateway logged that the configured Anthropic primary provider had no credentials and fell back to `openai-codex/gpt-6-sol`, while `hermes auth list` and `hermes auth status anthropic` in a login shell reported Anthropic as signed in.

Both read the same `HERMES_HOME`, but Hermes borrows the Anthropic login from Claude Code's `$CLAUDE_CONFIG_DIR/.credentials.json`, falling back to `~/.claude/.credentials.json` (`agent/anthropic_credentials.py`, `claude_code_credentials_path`). The upstream NixOS module sets `HOME` to `stateDir` (`/home/sgiath/hermes`) for its units, so the gateway looked for `/home/sgiath/hermes/.claude/.credentials.json`, which does not exist. The login shell has `HOME=/home/sgiath` and finds the real file.

## Decision

`modules/nixos/services/hermes-agent.nix` sets `services.hermes-agent.environment.CLAUDE_CONFIG_DIR` to `.claude` under `config.users.users.sgiath.home`. The upstream activation writes it into `HERMES_HOME/.env`, which the gateway loads at startup, the custom dashboard unit reads as its `EnvironmentFile`, and interactive Hermes commands load over shell exports. Every Hermes client on Vesta therefore reads the same file Claude Code uses.

The service runs as `sgiath`, so it reads the original file and refreshes the OAuth token in place. No credential is copied into Nix, the store or `HERMES_HOME`.

## Alternatives considered

- **Override `HOME` for the Hermes units.** Rejected: upstream and this configuration place state, the terminal working directory and tool paths under `stateDir` through `HOME`.
- **Copy or symlink `.claude/.credentials.json` into `stateDir`.** A copy diverges once either side refreshes the token; a symlink is an unmanaged file outside the module and still depends on the same path being correct.
- **Store an Anthropic API key in `hermes-env`.** Switches billing away from the Claude subscription login the user already maintains.

## Verification

A throwaway probe ran the real `claude_code_credentials_path`, `read_claude_code_credentials` and `hermes_cli.runtime_provider._anthropic_token_or_raise(model="claude-opus-5-5")` with the deployed service Python on Vesta, without printing token values. With the unit's `HOME` and `HERMES_HOME` it found no borrowed credentials and raised "No Anthropic credentials found". Adding only `CLAUDE_CONFIG_DIR=/home/sgiath/.claude` resolved the real credential path and a non-empty token for the configured model.

The setting only reaches `HERMES_HOME/.env`, not the unit files, so a switch does not restart Hermes; `hermes-agent.service` and `hermes-dashboard.service` must be restarted after activation for the gateway to pick it up.

The full Vesta NixOS build passes against an immutable source snapshot containing this change and the completed Mac-removal baseline. The production dotenv loader also passes a controlled check that the declared path reaches Anthropic credential resolution under the service home.

After the integrated full Vesta build and activation on 2026-10-12, both Hermes services were explicitly restarted. Under the real service home, the deployed dotenv and configuration resolve the Anthropic primary with no fallback, `hermes auth status anthropic` reports logged in, and the gateway journal contains no Anthropic missing-credential or primary-auth fallback warning after the restart. The original Claude credential file remains in the account home with mode `0600`. This verifies credential discovery and runtime selection; no conversation was sent as part of the check.
