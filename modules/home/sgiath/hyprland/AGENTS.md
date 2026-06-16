# modules/home/sgiath/hyprland

## OVERVIEW

Hyprland implementation shards imported by `modules/home/sgiath/hyprland.nix`; desktop behavior is split by concern, not by app.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Workspace/monitor map | parent `hyprland.nix`, `monitors.nix` | Hardcoded outputs: check host reality. |
| Keybindings | `keybindings.nix` | Binds often depend on package paths via `lib.getExe`. |
| Layout/look/animation | `layout.nix`, `looks.nix`, `general.nix` | Keep Hyprlang-compatible values. |
| Window rules | `rules.nix` | Class/title/workspace coupling. |
| Screenshot flow | `screenshot.nix` | CLI utilities and bind integration. |
| Colors | `color.nix` | Stylix/Hyprland-specific color handling. |

## CONVENTIONS

- Parent module sets `wayland.windowManager.hyprland.configType = "hyprlang"`; generated settings must stay Hyprlang-compatible.
- Stylix targets for Hyprland/fuzzel are disabled in the parent; do not assume Stylix owns this styling.
- Workspace rules are monitor-specific and tuned for `ceres`; avoid generalizing without checking host config.
- Hyprland-adjacent modules outside this directory (`waybar.nix`, `clipboard.nix`, `file_explorer.nix`) may depend on `programs.hyprland.enable`.

## ANTI-PATTERNS

- Do not rename monitor outputs, workspaces, or window classes without checking all rules/binds.
- Do not add generic desktop app enables here; use `targets/graphical.nix` or feature modules.
- Do not re-enable Stylix targets unless intentionally replacing the manual theme choices.
- Do not assume Waybar is active; graphical target currently disables it.

## VALIDATION

```bash
nixfmt modules/home/sgiath/hyprland/<file>.nix
nixos-rebuild switch --sudo --flake '.#ceres'
```
