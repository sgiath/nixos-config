# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-16
**Commit:** 8380fbec
**Branch:** master

## OVERVIEW

Personal NixOS/Home Manager configuration built with Snowfall Lib namespace `sgiath`. Hosts: `ceres` daily AMD desktop, `pallas` notebook, `vesta` home server, `hygiea` legacy/decommissioned host.

## STRUCTURE

```text
flake.nix                         # Snowfall Lib entry; overlays/modules wired here
systems/x86_64-linux/<host>/      # host NixOS configs; default/hardware/disko split
homes/x86_64-linux/sgiath@<host>/ # host Home Manager configs
modules/nixos/sgiath/             # shared workstation/system features
modules/nixos/server/             # service modules behind sgiath.server.enable
modules/home/sgiath/              # shared user modules and helper shell scripts
packages/                         # custom packages and update scripts
overlays/sgiath/default.nix       # selected packages from alternate nixpkgs channels
shells/default/default.nix        # dev/update toolchain
```

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Add/change host config | `systems/x86_64-linux/<host>/default.nix` | Role toggles only; keep hardware/disk layout separate. |
| Add/change user config | `homes/x86_64-linux/sgiath@<host>/default.nix` | Usually enables shared `modules/home/sgiath` profiles. |
| Shared NixOS feature | `modules/nixos/sgiath/` | Workstation baseline and opt-in hardware/service toggles. |
| Server service | `modules/nixos/server/` | Reverse proxies, `/data`, service ports, secrets. |
| Shared Home Manager feature | `modules/home/sgiath/` | User apps, profiles, agent tooling, shell helpers. |
| Custom package | `packages/<name>/` and `packages/default.nix` | Add/update package plus registry entry. |
| Package updater tooling | `shells/default/default.nix` | Add updater dependencies here, not via `nix-shell` shebangs. |
| Alternate nixpkgs package | `overlays/sgiath/default.nix` | Imports master/stable/ksa with repo channel config. |

## CODE MAP

| Symbol/Field | Location | Role |
| --- | --- | --- |
| `inputs` | `flake.nix` | 30+ flake inputs; includes local absolute `bird-src`. |
| `lib.mkFlake` | `flake.nix` | Snowfall Lib output generation; no manual `nixosConfigurations`. |
| `channels-config` | `flake.nix` | `allowUnfree`, ROCm enabled, CUDA disabled. |
| `systems.modules.nixos` | `flake.nix` | External NixOS modules exposed to all hosts. |
| `homes.modules` | `flake.nix` | External Home Manager modules exposed to all homes. |
| `sgiath.enable` | `modules/nixos/sgiath/default.nix` | Main shared system gate. |
| `sgiath.server.enable` | `modules/nixos/server/default.nix` | Main server-module gate. |
| `packages/default.nix` attrs | `packages/default.nix` | Hand-maintained local package registry. |

## CONVENTIONS

- Snowfall discovers `systems`, `homes`, `modules`, `packages`, `overlays`, `shells`; do not add manual output lists unless replacing Snowfall behavior.
- Modules use `options.<scope>.enable = lib.mkEnableOption ...` plus `config = lib.mkIf config.<scope>.enable ...`.
- Main NixOS/Home Manager state versions are `23.11`; do not bump casually.
- Secrets are loaded from encrypted `secrets.json` via `builtins.fromJSON`; server runtime secret files usually live under `/data/secrets`.
- New files must be `git add`ed before Nix flake evaluation can see them.
- Format Nix with `nixfmt`; use `nix develop` for `nixd`, `nil`, `shfmt`, `prettier`, and update helpers.
- Do not evaluate Home Manager outputs directly; Stylix Home Manager wiring is provided through the NixOS Stylix module. Validate homes as part of the full NixOS system evaluation/build.

## ANTI-PATTERNS

- Never delete the `result` symlink; leave it for the user.
- Do not use `nix-shell` shebangs in new update scripts; add missing tools to `shells/default/default.nix`.
- Do not compute hashes before detecting that an updater's version actually changed.
- Do not copy `packages/relay-tester/update.sh`'s `nix-shell` lockfile step into new scripts; treat it as legacy.
- Do not widen `secrets.json` usage or introduce new plaintext secret paths.
- Do not treat `hygiea` as an active primary host; it is retained legacy config.
- Destructive git ops are forbidden unless explicit: no reset, clean, restore, force-push.

## COMMANDS

```bash
nix develop
nixfmt <file.nix>
nix flake update
nix build '.#<package>'
nix build '.#install-isoConfigurations.live'
nixos-rebuild switch --sudo --flake .
nixos-rebuild switch --sudo --flake '.#ceres'
NIX_SSHOPTS="-o IdentityAgent=$SSH_AUTH_SOCK" nixos-rebuild switch --sudo --flake '.#vesta' --target-host 'vesta.local'
```

## NOTES

- No in-repo CI, `checks`, `nixosTests`, pre-commit config, Makefile, or justfile found; validation is manual builds/rebuilds.
- Custom user commands `update`, `update-limited`, `clear-cache` are defined in `modules/home/sgiath/default.nix`; `update*` commits and pushes before rebuilding.
- `clear-cache` runs Nix GC, Docker prune, and journal vacuum; treat as destructive maintenance.
- `dnd5etools` has a separate image hash updater; package `update.sh` alone is incomplete if image assets changed.
