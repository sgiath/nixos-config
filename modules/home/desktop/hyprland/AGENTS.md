# modules/home/desktop/hyprland

## OVERVIEW

Hyprland implementation shards imported by `modules/home/desktop/hyprland.nix`; desktop behavior is split by concern, not by app.

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

- Parent module sets `wayland.windowManager.hyprland.configType = "lua"`; keep settings compatible with Home Manager's Hyprland Lua serializer.
- Stylix targets for Hyprland/fuzzel are disabled in the parent; do not assume Stylix owns this styling.
- Workspace rules are monitor-specific and tuned for `ceres`; avoid generalizing without checking host config.
- Hyprland-adjacent modules outside this directory (`clipboard.nix`, `yazi.nix`) gate on `sgiath.roles.desktop.enable`.

## ANTI-PATTERNS

- Do not rename monitor outputs, workspaces, or window classes without checking all rules/binds.
- Do not add generic desktop app enables here; use `desktop/default.nix` or `programs/` feature modules.
- Do not re-enable Stylix targets unless intentionally replacing the manual theme choices.
- Do not drop the `no_anim` layer rule for slurp's `selection` namespace in `screenshot.nix`: Hyprland fades out a snapshot of an unmapped layer, and grim would capture the selection border and fill through it.

## VALIDATION

```bash
nixfmt modules/home/desktop/hyprland/<file>.nix
nixos-rebuild switch --sudo --flake '.#ceres'
```
