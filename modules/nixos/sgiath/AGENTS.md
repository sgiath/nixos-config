# modules/nixos/sgiath

## OVERVIEW

Shared workstation/system baseline behind `sgiath.enable`, plus opt-in hardware and local service toggles.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Import/gate overview | `default.nix` | Always-on imports vs feature toggles. |
| Boot/kernel defaults | `boot.nix` | Host-wide boot policy; some host branching. |
| GPU choice | `graphics.nix`, `amd-gpu.nix`, `nvidia-gpu.nix` | Nullable enum-style `sgiath.gpu`. |
| Network quirks | `networking.nix`, `yggdrasil.nix` | `mkMerge`/`mkIf` layering and host-specific peers. |
| Desktop/session | `wayland.nix`, `stylix.nix` | Greetd/Hyprland/session environment. |
| Runtime stacks | `audio.nix`, `docker.nix`, `ollama.nix`, `comfyui.nix` | Feature flags may add groups/services. |

## CONVENTIONS

- Root gate is `options.sgiath.enable`; many baseline modules are imported always but activated under that gate.
- Feature modules add their own options under `sgiath.*` or existing NixOS option namespaces.
- Keep workstation concerns here: shell/user defaults, GPU, audio, input devices, desktop session, local dev/runtime services.
- `secrets.json` is read relative to this tree in `default.nix`; avoid adding more eval-time secret reads unless necessary.
- Host-specific branching exists but should stay narrow and explicit.

## ANTI-PATTERNS

- Do not put server reverse proxies or `/data` service state here; use `modules/nixos/server`.
- Do not broaden nullable GPU logic beyond existing `amd`/`nvidia`/unset behavior without checking hosts.
- Do not add user-facing Home Manager config here; use `modules/home/sgiath`.
- Do not add feature side effects without documenting groups, firewall, service ordering, or required host toggles.

## VALIDATION

```bash
nixfmt modules/nixos/sgiath/<file>.nix
nixos-rebuild switch --sudo --flake '.#ceres'
```
