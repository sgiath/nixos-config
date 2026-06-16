# modules/home/sgiath

## OVERVIEW

Shared Home Manager modules for user apps, shells, profiles, desktop config, and agent tooling.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Import list and shell helpers | `default.nix` | Defines `update`, `update-limited`, `clear-cache`. |
| Profile split | `targets/graphical.nix`, `targets/terminal.nix` | Main desktop vs CLI boundary. |
| Hyprland desktop | `hyprland.nix`, `hyprland/` | Window manager and hardcoded monitor/workspace rules. |
| Agent tooling | `agents/` | Has its own `AGENTS.md`; follow it in that subtree. |
| Browser/editor/CLI apps | feature `.nix` files | Usually gated by module-specific enable options. |

## CONVENTIONS

- `default.nix` is an aggregator plus always-available helper scripts; avoid unrelated logic there.
- `sgiath.targets.terminal` enables CLI/editor/agent stack; `sgiath.targets.graphical` enables desktop apps and Hyprland-adjacent services.
- Feature modules usually expose `programs.<name>.enable`, `services.<name>.enable`, or `sgiath.<feature>.enable`.
- Agent tooling intentionally writes some tool-local config/memory files; do not over-normalize it into pure Nix state.
- `agents/default.nix` has a small graphical coupling for `t3code`; preserve profile awareness.

## ANTI-PATTERNS

- Do not put host-specific NixOS services here; use `systems/` or `modules/nixos`.
- Do not move profile-wide app enables into individual host homes without a reason.
- Do not duplicate rules from `agents/AGENTS.md`; that file governs agent skills/configs.
- Do not run or edit the `update*` helper scripts casually; they commit and push before rebuilding.

## VALIDATION

```bash
nixfmt modules/home/sgiath/<file>.nix
nixos-rebuild switch --sudo --flake '.#ceres'
```
