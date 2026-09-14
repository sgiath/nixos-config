# systems/x86_64-linux

## OVERVIEW

Per-host NixOS entry points. Host directory name should match `networking.hostName`.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Host roles/hardware | `<host>/default.nix` | `sgiath.enable`, `sgiath.hardware.*`, `sgiath.roles.*`, `virtualisation.docker.enable`, host-only secrets. |
| Server service list | `<host>/services.nix` | `services.<name>.enable` and `sgiath.sites.<name>.enable` toggles; servers only. |
| Hardware details | `<host>/hardware.nix` | Boot, filesystems, swap, low-level network. |
| Disk layout | `<host>/disko.nix` | Only where declarative disk layout exists. |
| Shared feature logic | `../../modules/nixos/` | Do not duplicate shared module code in hosts. |

## CONVENTIONS

- `ceres`: AMD desktop; `roles.desktop` + `roles.gaming`, `hardware.gpu = "amd"`, xanmod kernel in `hardware.nix`. Carries the build-signing key (`nix-signing-key` sops secret + `nix.settings.secret-key-files`), `openclaw-token`, and the LAN yggdrasil peers.
- `pallas`: Nvidia notebook; `roles.desktop` + `roles.laptop`, `hardware.gpu = "nvidia"`, `hardware.razer.enable`. No gaming role (dual-boot disk space).
- `vesta`: headless home server; `roles.server`, `disko.nix`, `networking.wireguard.enable = false`; every service/site toggle lives in `services.nix`.
- Every host sets `sgiath.enable = true` and `virtualisation.docker.enable = true`.
- Roles are additive; hardware options are one-of. Home Manager roles (`terminal`, `desktop`, `gaming`) are pushed from the NixOS side, so homes do not repeat them.
- Host-only secrets (sops secrets that exist on exactly one machine) are declared in that host's `default.nix`, not in shared modules.
- Keep `default.nix` declarative and role-level; hardware UUIDs and disk topology stay out.

## ANTI-PATTERNS

- Do not move generated hardware config into shared modules.
- Do not copy service definitions into host files; add/tune modules under `modules/nixos/services` or `modules/nixos/sites`.
- Do not gate shared modules on `networking.hostName`; add a role or hardware option, or put the host-only piece here.
- Do not treat `disko.nix` as optional cleanup; it is part of reproducible host state where present.

## VALIDATION

```bash
nixos-rebuild switch --sudo --flake '.#ceres'
update --vesta
```
