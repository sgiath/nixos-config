# Agent Note: Native harnesses and updated model routing

Status: implemented

## Problem

Routing every role through OpenCode (`opencode` / `cliproxy/*`) and sending Codex and Grok inference through CLIProxyAPI split the native setups across workarounds:

- Codex defaulted to `model_provider = "cliproxy"` in `/etc/codex/config.toml`, which could not serve `gpt-daybreak-blue-latest`, forcing a separate `codex-daybreak` T3 instance and `~/.codex/daybreak.config.toml` profile.
- Grok's `~/.grok/config.toml` received all 18 CLIProxy models, switched `grok-4.7` to `chat_completions` over CLIProxyAPI, and sent Grok's helper slots (`web_search`, `session_summary`, `image_description`, `prompt_suggestion`, `fork_secondary_model`) to GPT models.
- T3 Code's bundled `claudeAgent` catalog omits `claude-mythos-5-2` (and Claude Code hides subscription-only models from `supportedModels()` when `ANTHROPIC_BASE_URL` is set), which pushed Mythos sessions into OpenCode.
- Gemini 4 Neon in Antigravity had no place in the shared routing instructions or `council`, and `auto-review` defaulted to `opencode` / `cliproxy/claude-opus-5-5`.

## Decision

Every subscription's models run in that provider's native harness, never through a third-party harness or another provider's harness:

- **Antigravity (`antigravity`, `agy`)** for Gemini models, native Google login directly.
- **Claude Code (`claudeAgent`, `claude`)** for Anthropic models. Claude Code keeps CLIProxyAPI (`modules/home/agents/claude.nix`) solely to share the two Claude subscriptions and route `claude-mythos-5-2` to the personal login; activation (`t3codeClaudeMythos`) registers `claude-mythos-5-2` in T3's `providerInstances.claudeAgent.config.customModels` with its `effort` options so it works directly on `claudeAgent`.
- **Codex (`codex`, `codex`)** for OpenAI models, native OpenAI login directly (`modules/nixos/common/codex.nix` drops `model_provider = "cliproxy"`, keeping only `otel`; `modules/home/agents/codex.nix` stops generating `codex-daybreak` and `daybreak.config.toml`).
- **Grok (`grok`, `grok`)** for Grok models, native xAI login directly (`modules/home/agents/cliproxy.nix` drops `grokProxy`; `modules/home/agents/grok.nix` removes CLIProxy `[model.*]` overrides, proxy `allowed_models`, and non-Grok helper defaults from `~/.grok/config.toml`; Grok 1.0.92 loads `~/.claude/CLAUDE.md` and `~/.claude/skills/` automatically via Claude compatibility).
- `services.auto-review` defaults to `codex` / `gpt-6.2-sol` / `high` (matching the review routing), recognizes Antigravity's `thought_level` option in `auto_review/t3.py`, and names `Antigravity harness` and `Grok harness` in `auto_review/publish.py`.

Role routing in [`AGENTS.md`](../../../../modules/home/agents/AGENTS.md), [`verified-work`](../../../../modules/home/agents/skills/verified-work/SKILL.md) and the downstream skills (`council`, `sol-loop`, `drive`, `own-change`, `research`, `self-review`) updates to:

- **Gemini 4 Neon** (`antigravity`, `gemini-4-neon`): default general and production-code model; **Opus 5.5** (`claudeAgent`, `claude-opus-5-5`) is its peer when a thread already runs on Opus or is selected by sgiath.
- **Fable 5.2** (`claudeAgent`, `claude-fable-5-2`, `high`) and **Astra** (`codex`, `gpt-6.2-astra`, `high`): consulting on plans and complex design decisions; Fable also handles new UI designs (sparingly) and the review rounds' single ship check.
- **Sol** (`codex`, `gpt-6.2-sol`): thorough evidence work, throwaway proof tests, independent verification, second diagnoses, parallel side investigations, and independent code review (`high`).
- **Mythos 5.2** (`claudeAgent`, `claude-mythos-5-2`, `high`): cybersecurity-sensitive plans and complex security-critical code reviews.
- **Daybreak Blue** (`codex`, `gpt-daybreak-blue-latest`, `high`): routine adversarial security reviews.
- **Grok 4.7** (`grok`, `grok-4.7`, `high`): independent cross-family perspective in `council` (now four native harnesses: Codex Sol, Claude Opus, Antigravity Gemini 4 Neon, Grok 4.7).

## Alternatives considered

- **Drop CLIProxyAPI from Claude Code too.** Would require managing two separate Claude Code home directories (`~/.claude` and a second profile) and switching between them manually instead of rotating across both subscriptions and routing Mythos automatically.
- **Keep CLIProxyAPI behind Codex and Grok.** Keeps Codex unable to serve `gpt-daybreak-blue-latest` on the default instance and keeps Grok on `chat_completions` instead of xAI's native Responses backend.
- **Keep OpenCode as the shared harness.** Conflicts with running every subscription in its native harness and disables provider-native features.

## Consequences

- Codex and Grok stop sending inference through CLIProxyAPI, so `agents.cliproxy_requests` and CLIProxy passive quota headers only see Claude Code (plus Hermes on Vesta and any manual OpenCode/Pi/fx runs, which remain pointed at CLIProxyAPI for now). Quickshell's `usage-collector` continues to report Codex, Gemini and Grok through its `api-call` path on CLIProxyAPI's stored accounts.
- App-owned `~/.t3/userdata/settings.json` files on already-activated hosts keep any pre-existing `codex-daybreak` instance, Vesta's `opencode2` instance, and `CrazyEgg` `projectSettingsOverrides` pointing at `opencode`/`opencode2` until updated in T3 UI after switching.
- Rollout prerequisite: native logins exist on Ceres and Vesta for Codex, Grok and Antigravity; Pallas is not logged in to native Codex (`codex -c model_provider=openai login status`), Grok, or Antigravity yet and needs interactive logins before switching or relying on those harnesses there.
- Supersedes the OpenCode harness and Opus-only implementation routing in [Opus does its own short work, Sol takes long and independent work](2026-11-18-opus-sol-routing.md); that note's short-vs-long delegation rule still stands.
