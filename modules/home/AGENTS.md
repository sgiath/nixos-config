# modules/home

## OVERVIEW

Home Manager modules for user `sgiath`, split by role. Snowfall imports every `<dir>/default.nix` into every home; everything is gated by options, never by import selection. Only the top-level `default.nix` per directory is auto-discovered; subdirectories hold plain `*.nix` files imported explicitly by the parent.

## WHERE TO LOOK

| Task | Location | Gate |
| --- | --- | --- |
| Baseline packages, direnv, pass, API-key secrets | `common/` | `sgiath.enable` |
| CLI stack: git, gpg, ssh, zsh, starship, tmux, worktrunk, agents | `terminal/` | `sgiath.roles.terminal.enable` |
| Hyprland, stylix, terminals, clipboard, voxtype, chromium | `desktop/` | `sgiath.roles.desktop.enable` |
| Desktop shell choice (Noctalia vs in-repo Quickshell), `desktop-shell` CLI, shell keybinds | `desktop/shell.nix` | `sgiath.desktop.shell`; both units installed, `Conflicts` each other |
| Own Quickshell config (QML in `desktop/quickshell/`, Stylix theme JSON, qmlls) | `desktop/quickshell.nix` | `programs.quickshell.enable`; `sgiath.desktop.quickshell.live` symlinks `~/nixos/.../quickshell` for hot reload |
| Noctalia settings and layer rules | `desktop/noctalia.nix` | `programs.noctalia.enable` |
| Hyprland shards and monitor/workspace rules | `desktop/hyprland/` | Has its own `AGENTS.md`. |
| Desktop app groups | `programs/` | `sgiath.programs.{audio,bitcoin,browsers,chat,editors,email}.enable` |
| Games (lutris, prismlauncher, factorio) | `gaming/` | `sgiath.roles.gaming.enable` |
| Agent tooling | `agents/` | `sgiath.agents.enable`; has its own `AGENTS.md`. |
| CrazyEgg / Remote work setups | `work/` | `sgiath.work.{crazyegg,remote}.enable` |

Themes referenced by `desktop/stylix.nix` live in `themes/` at the repo root.

## CONVENTIONS

- Roles are pushed from NixOS (`modules/nixos/{common,desktop,gaming}`): `sgiath.enable` and `roles.terminal` from common, `roles.desktop` from the desktop role, `roles.gaming` from the gaming role. Host homes only set host-specific extras.
- Group options are declared in the group's `default.nix` (`programs/default.nix`, `work/default.nix`); each feature keeps its `config = mkIf ...` in its own file.
- The desktop role enables `sgiath.programs.*`; Hyprland-adjacent files gate on `sgiath.roles.desktop.enable`, upstream-style files on `programs.<name>.enable`.
- Agent tooling intentionally writes some tool-local config/memory files; do not over-normalize it into pure Nix state.
- `agents/t3code.nix` owns the T3 Code CLI, optional desktop package, and user service; on Vesta the NixOS `services.t3code` module enables it and exposes it as `t3.sgiath.dev`.

## ANTI-PATTERNS

- Do not add a `default.nix` inside a subdirectory; Snowfall would import it as its own module.
- Do not reference `pkgs` in a `<dir>/default.nix`; Snowfall substitutes its channel `pkgs` there (no Stylix overlays). Bodies live in `role.nix`/`base.nix`/feature files.
- Do not put host-specific NixOS services here; use `systems/` or `modules/nixos`.
- Do not move role-wide app enables into individual host homes without a reason.
- Do not duplicate rules from `agents/AGENTS.md`; that file governs agent skills/configs.
- Do not run or edit the `update*` helper scripts casually; they commit and push before rebuilding.

## VALIDATION

```bash
nixfmt modules/home/<dir>/<file>.nix
nixos-rebuild switch --sudo --flake '.#ceres'
```
