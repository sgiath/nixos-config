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
| Desktop app groups | `programs/` | `sgiath.programs.{audio,bitcoin,blender,browsers,chat,editors,email}.enable` |
| Games (lutris, prismlauncher, factorio) | `gaming/` | `sgiath.roles.gaming.enable` |
| Agent tooling | `agents/` | `sgiath.agents.enable`; has its own `AGENTS.md`. |
| CrazyEgg / Remote work setups | `work/` | `sgiath.work.{crazyegg,remote}.enable` |

Themes referenced by `desktop/stylix.nix` live in `themes/` at the repo root.

## CONVENTIONS

- Roles are pushed from NixOS (`modules/nixos/{common,desktop,gaming}`): `sgiath.enable` and `roles.terminal` from common, `roles.desktop` from the desktop role, `roles.gaming` from the gaming role. Host homes only set host-specific extras.
- Group options are declared in the group's `default.nix` (`programs/default.nix`, `work/default.nix`); each feature keeps its `config = mkIf ...` in its own file.
- The desktop role enables `sgiath.programs.*`; Hyprland-adjacent files gate on `sgiath.roles.desktop.enable`, upstream-style files on `programs.<name>.enable`.
- Agent tooling intentionally writes some tool-local config/memory files; do not over-normalize it into pure Nix state.
- Shared MCP servers go in `programs.mcp.servers`; Claude Code and OpenCode read them through `enableMcpIntegration`, and `agents/omp.nix` renders them into `~/.omp/agent/mcp.json`, so OMP's `/mcp add` at user level does not persist. Codex's `~/.codex/config.toml` is unmanaged.
- `programs/blender.nix` is enabled per host (Ceres), not by the desktop role, because of its closure size. With agents enabled it wraps Blender to load the Blender Lab MCP add-on (`bl_ext.system.mcp`, localhost:9876, `--online-mode`) and registers the `blender` MCP server.
- `agents/t3code.nix` owns the T3 Code CLI, optional desktop package, and user service. The server binds the host's Nebula address (never a wildcard); on Vesta the NixOS `services.t3code` module enables it on loopback and exposes it as `t3.sgiath.dev`. `services.t3code.channel = "nightly"` (set per host in `homes/`, Ceres and Vesta today) swaps both CLI and desktop app from llm-agents to the prebuilt upstream nightlies in `packages/t3code-nightly{,-desktop}`, and links `packages/t3code-nightly-device-tools` into `~/.t3/tools` (an activation step first deletes a copy T3 npm-installed there itself, which would block the link); nightly and stable share `~/.t3`, and the first nightly start imports the stable `state.sqlite` into a new `statev2.sqlite`. Keep hosts the desktop reaches on the same channel: its SSH environments reuse the remote user service's server, and the nightly client (orchestration protocol 2) treats a stable server (protocol 1) as outdated. The two desktop builds encrypt `~/.t3/userdata/connection-catalog.json` (saved environments) with different Secret Service keys (application `T3 Code (Alpha)` for stable, `t3code` for the nightly AppImage), so a channel switch leaves the catalog unreadable and the app never connects; re-add the environments, or decrypt and re-encrypt the file with the other key (Chromium `v11`: PBKDF2-SHA1 of the keyring password, salt `saltysalt`, 1 iteration, AES-128-CBC, IV of 16 spaces).
- `agents/herdr-server.nix` owns the default Herdr daemon and installed startup launcher (`X-SwitchMethod = keep-old` preserves panes during rebuilds). Ceres enables it independently of the web UI; on desktops it requires the graphical session, clears SSH markers, waits for live sockets, and stops at logout. `agents/herdr-web.nix` enables the daemon alongside the web service; Vesta exposes that UI as `herdr.sgiath.dev`. `agents/herdr-thread.nix` provides `herdr-thread <branch> <prompt>` (worktree + herdr workspace + OMP).

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
