# systems/x86_64-linux

## OVERVIEW

Per-host NixOS entry points. Host directory name should match `networking.hostName`.

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Host role/features | `<host>/default.nix` | Service/profile toggles only. |
| Hardware details | `<host>/hardware.nix` | Boot, filesystems, swap, low-level network. |
| Disk layout | `<host>/disko.nix` | Only where declarative disk layout exists. |
| Shared feature logic | `../../modules/nixos/sgiath/` | Do not duplicate shared module code in hosts. |
| Server services | `../../modules/nixos/server/` | Enable from host via `sgiath.server.enable`. |

## CONVENTIONS

- `ceres`: active AMD desktop/gaming workstation; primary default target.
- `pallas`: notebook; host-specific networking/display quirks belong here.
- `vesta`: home server; imports `disko.nix`, enables `sgiath.server`, toggles services.
- `hygiea`: legacy/decommissioned offsite/VM host; preserve unless user asks.
- Keep `default.nix` declarative and role-level; hardware UUIDs and disk topology stay out.
- Desktops usually enable `sgiath.enable`; server hosts add `sgiath.server.enable`.

## ANTI-PATTERNS

- Do not move generated hardware config into shared modules.
- Do not copy service definitions into host files; add/tune modules under `modules/nixos/server` or `modules/nixos/sgiath`.
- Do not treat `disko.nix` as optional cleanup; it is part of reproducible host state where present.
- Do not remove `hygiea` just because it is decommissioned.

## VALIDATION

```bash
nixos-rebuild switch --sudo --flake '.#ceres'
NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK" nixos-rebuild switch --sudo --flake '.#vesta' --target-host 'vesta.local'
nixos-rebuild switch --sudo --flake '.#hygiea' --target-host 'sgiath@hygiea.sgiath.dev'
```
