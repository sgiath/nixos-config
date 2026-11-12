# Agent Note: Hermes reaches its models through CLIProxy

Status: implemented

## Problem

Hermes on Vesta held its own model logins: Anthropic borrowed Claude Code's `~/.claude/.credentials.json` through `CLAUDE_CONFIG_DIR` ([archived note](../../archived/bug-fix/2026-10-12-hermes-claude-credentials.md)), and `openai-codex` and `xai-oauth` kept OAuth tokens in `HERMES_HOME`. Each login expired or broke on its own schedule. On 2026-11-12 the 06:00 `AI News Digest` cron run found no Anthropic access token in the borrowed file, fell back to `openai-codex/gpt-6-sol`, and got HTTP 401 `invalid_jwt` from `chatgpt.com/backend-api/codex`, so the job failed. CLIProxyAPI on the same host already maintains working Claude, Codex and Grok logins for every other client.

## Decision

`modules/nixos/services/hermes-agent.nix` declares three named Hermes providers pointing at CLIProxy on loopback (`services.cliproxyapi.settings.server.port`), one per wire protocol:

| Provider | Base URL | `api_mode` | Used for |
| --- | --- | --- | --- |
| `cliproxy-claude` | `http://127.0.0.1:<port>` | `anthropic_messages` | main model, delegation, MoA aggregator and Claude reference |
| `cliproxy-codex` | `…/v1` | `codex_responses` | fallback, auxiliary tasks, MoA GPT reference |
| `cliproxy-chat` | `…/v1` | `chat_completions` | MoA Grok reference |

Model names are unchanged; they are bare, so they reach only the personal CLIProxy accounts (`routing.force-model-prefix`). Cron jobs without a provider pin inherit the main model and fallback.

Each provider reads `api_key_env = "CLIPROXY_API_KEY"`. A sops template `hermes-cliproxy-env` renders `CLIPROXY_API_KEY=<cliproxy_api_key>` and is added to `environmentFiles`, which the upstream activation concatenates into `HERMES_HOME/.env`. The template restarts both Hermes units when it changes. `CLAUDE_CONFIG_DIR` is no longer set. An assertion requires `services.cliproxyapi` on the same host, and `hermes-agent.service` starts after it.

Named `providers` entries are required: bare `custom` ignores `api_mode = codex_responses` for an unrecognized host (`hermes_cli/runtime_provider.py`), native `anthropic` rejects a loopback `base_url`, and `openai` is an OpenRouter alias in this Hermes version.

`tts` and `x_search` still use Hermes's own xAI credentials; they resolve them separately from the model providers.

## Alternatives considered

- **Keep native logins and repair them.** Leaves three independent OAuth states in `HERMES_HOME` and the borrowed Claude Code file, which is what failed.
- **One `custom` provider for everything.** Loses the Responses transport for GPT models and the Anthropic Messages transport (effort, cache markers) for Claude.
- **Go through `https://cliproxy.sgiath.dev`.** Adds nginx and TLS on the same host for no benefit; loopback needs no Nebula.

## Consequences

- Hermes's model access depends on `cliproxyapi.service`; login problems are fixed once in the CLIProxy panel for every client.
- Hermes treats CLIProxy as a third-party Anthropic endpoint and strips replayed thinking blocks from history (`agent/anthropic_message_convert.py`). Effort, cache markers and tool schemas are still sent.
- Old OAuth entries in `HERMES_HOME/auth.json` stay on disk unused; `hermes auth` may still list them.
- Usage now appears in `agents.cliproxy_requests` alongside other clients.

Before the change, throwaway probes with the deployed Hermes Python and a scratch `HERMES_HOME` on Vesta returned a reply through `AIAgent` on `claude-opus-5-5` (Anthropic Messages, high effort), through the configured `auxiliary.title_generation` on `gpt-6-luna` (Responses) and through `grok-4.7` (Chat Completions).
