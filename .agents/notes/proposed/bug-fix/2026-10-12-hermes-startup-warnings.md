# Agent Note: Review Hermes startup warnings after the core/plugin split

Status: proposed

## Problem

Hermes v0.21.7 on Vesta reports several startup warnings independent of the Holographic memory failure:

- `session_reset.mode = "both"` no longer controls gateway resets. The idle/daily policy moved to the `hermes-session-reset-policy` plugin; core resets only on `/new` or `/reset`.
- The systemd unit has a 5-second stop timeout while the gateway requests at least 70 seconds to allow its cron drain to finish.
- Some joined Matrix rooms are encrypted, but the configured process has no E2EE decryptor. Messages from those rooms are dropped. Encryption is explicitly disabled in this configuration, so enabling it requires confirming the intended room scope.

These were observed in the gateway journal on 2026-10-12 after restarting the service for the memory fix. They do not prevent built-in memory initialization or searching the existing session database. The missing Anthropic credentials warning from the same startup is resolved separately in [Hermes service borrows the account's Claude Code login](../../implemented/bug-fix/2026-10-12-hermes-claude-credentials.md).

## Proposal

Decide whether idle/daily resets and encrypted-room support remain desired. Match the service stop timeout to the gateway drain configuration. Package any selected policy or encryption dependencies declaratively rather than installing into the immutable Python environment at runtime.

## Acceptance criteria

- Gateway reset behavior matches the chosen policy and its plugin is available if needed.
- The stop timeout accommodates the configured gateway and cron drain.
- Encrypted rooms either work with the intended encryption configuration or are deliberately excluded; do not silently override the existing encryption decision.
- Validate the full Vesta NixOS configuration and actual gateway startup without these unresolved warnings.
