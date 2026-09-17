# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-16
**Commit:** 8380fbec
**Branch:** master

## OVERVIEW

Personal NixOS/Home Manager configuration built with Snowfall Lib namespace `sgiath`. Hosts: `ceres` daily AMD desktop, `pallas` notebook, `vesta` home server, `juno<N>` NVIDIA DGX Spark compute nodes (aarch64, headless; `juno1` first).

## STRUCTURE

```text
flake.nix                         # Snowfall Lib entry; overlays/modules wired here
systems/<arch>/<host>/            # host NixOS configs; default/hardware/disko split, services.nix on servers (x86_64-linux, aarch64-linux)
homes/<arch>/sgiath@<host>/       # host Home Manager configs (host-only extras; roles come from NixOS)
modules/nixos/common/             # baseline under sgiath.enable: users, nix, boot, secrets, networking
modules/nixos/hardware/           # one-of hardware: sgiath.hardware.{gpu,boot,razer,dgx-spark}
modules/nixos/{desktop,laptop,server,gaming}/ # additive roles: sgiath.roles.<role>.enable
modules/nixos/services/           # one file per service, hooked on services.<name>.enable
modules/nixos/sites/              # nginx vhosts, sgiath.sites.<name>.enable
modules/home/common/              # baseline under HM sgiath.enable
modules/home/{terminal,desktop,gaming}/ # HM roles: sgiath.roles.<role>.enable (pushed from NixOS)
modules/home/programs/            # opt-in program groups: sgiath.programs.<group>.enable
modules/home/agents/              # agent tooling and services (cli-proxy-api, t3code, ...)
modules/home/work/                # sgiath.work.{crazyegg,remote}.enable
themes/                           # base16 schemes shared by NixOS and HM stylix
secrets/                          # SOPS files plus the public ceres-cache.pub signing key; nebula.yaml (host certs), nebula-ca.yaml (CA key, PGP-only)
scripts/                          # update-inputs.sh, nebula-sign.sh, nebula-mobile.sh
packages/                         # custom packages, update/clear-cache commands, updater scripts
overlays/sgiath/default.nix       # selected packages from alternate nixpkgs channels
shells/default/default.nix        # dev/update toolchain
```

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Add/change host config | `systems/<arch>/<host>/default.nix` | Role/hardware toggles and host-only secrets; keep hardware/disk layout separate. |
| Server service list | `systems/x86_64-linux/vesta/services.nix` | `services.<name>.enable` and `sgiath.sites.<name>.enable`. |
| Add/change user config | `homes/<arch>/sgiath@<host>/default.nix` | Host-only packages, work toggles, font sizes; HM roles are pushed from NixOS. |
| Shared NixOS baseline | `modules/nixos/common/` | Everything every host gets under `sgiath.enable`. |
| Hardware variant | `modules/nixos/hardware/` | GPU vendor, kernel, boot mode, Razer, DGX Spark platform. |
| Machine role | `modules/nixos/<role>/` | `desktop`, `laptop`, `server`, `gaming`; each pushes its HM role. |
| Server service | `modules/nixos/services/<name>.nix` | `/data`, ports, secrets; file named after the option. |
| Reverse-proxied site | `modules/nixos/sites/<name>.nix` | nginx vhost behind `sgiath.sites.<name>.enable`. |
| Shared Home Manager feature | `modules/home/<group>/` | `common`, `terminal`, `desktop`, `programs`, `gaming`, `agents`, `work`. |
| Custom package | `packages/<name>/` and `packages/default.nix` | Add/update package plus registry entry. |
| Package updater tooling | `shells/default/default.nix` | Add updater dependencies here, not via `nix-shell` shebangs. |
| Alternate nixpkgs package | `overlays/sgiath/default.nix` | Imports master/stable/ksa with repo channel config. |

## CODE MAP

| Symbol/Field | Location | Role |
| --- | --- | --- |
| `inputs` | `flake.nix` | External flake inputs; Bird uses `vendor/bird` instead of the unavailable upstream/local absolute `bird-src` input. |
| `lib.mkFlake` | `flake.nix` | Snowfall Lib output generation; no manual `nixosConfigurations`. |
| `channels-config` | `flake.nix` | `allowUnfree`, ROCm enabled, CUDA disabled. |
| `systems.modules.nixos` | `flake.nix` | External NixOS modules exposed to all hosts. |
| `homes.modules` | `flake.nix` | External Home Manager modules exposed to all homes. |
| `sgiath.enable` | `modules/nixos/common/default.nix` | Main shared system gate; pushes HM `sgiath.enable` + `roles.terminal`. |
| `sgiath.nebula.{domain,peers}` / `services.nebula.networks.sgiath` | `modules/nixos/common/nebula.nix` | Dual-stack overlay `10.42.0.0/24` + `fd51:da00:4788::/64` on every host (v2 certs). Read-only `peers` table (hostname → `ip4`/`ip6`) picks `<host>_cert`/`<host>_key` from `secrets/nebula.yaml` and feeds `<host>.nebula.sgiath.dev` A/AAAA into `networking.hosts` and Pi-hole (`services/pi-hole.nix`, `services.pihole-ftl.settings.dns.hosts`). Vesta sets `isLighthouse`/`isRelay` in its host config; lighthouse address is `nebula.sgiath.dev:4242` (DNS-only record; LAN via hosts entry). |
| `sgiath.hardware.*` | `modules/nixos/hardware/default.nix` | `gpu` (`null`/`amd`/`nvidia`), `boot` (`uefi`/`legacy`), `razer.enable`, `dgx-spark.enable` (wraps `inputs.dgx-spark` module: NVIDIA 6.17 kernel, open driver, CUDA, podman, ConnectX-7). |
| `sgiath.roles.desktop.enable` | `modules/nixos/desktop/default.nix` | Wayland, audio, bluetooth, printing, Stylix; pushes HM `roles.desktop`. |
| `sgiath.roles.laptop.enable` | `modules/nixos/laptop/default.nix` | NetworkManager + public DNS `resolv.conf`. |
| `sgiath.roles.server.enable` | `modules/nixos/server/default.nix` | Main server-module gate; nginx, minecraft, trusts `secrets/ceres-cache.pub`. |
| `sgiath.roles.gaming.enable` | `modules/nixos/gaming/default.nix` (body in `role.nix`) | Steam/wine/gamescope/gamemode, factorio token; pushes HM `roles.gaming`. |
| `sgiath.sites.<name>.enable` | `modules/nixos/sites/default.nix` | nginx vhosts: `sgiath-dev`, `sinai-camp`, `nas`, `eve`, `ai`. |
| `services.<name>.enable` | `modules/nixos/services/<name>.nix` | Local services (upstream option or declared there). |
| HM `sgiath.roles.*` | `modules/home/{terminal,desktop,gaming}/default.nix` | User-side role bodies; set from NixOS, not from homes. |
| HM `sgiath.programs.*` | `modules/home/programs/default.nix` | `audio`, `bitcoin`, `chat`, `editors`, `email`, `browsers`. |
| HM `sgiath.work.*` | `modules/home/work/default.nix` | `crazyegg`, `remote`. |
| HM `sgiath.desktop.*` | `modules/home/desktop/default.nix` | `shell` (`noctalia`/`sgiath`, login default; `desktop-shell` switches live), `quickshell.live` (QML from `~/nixos` checkout with hot reload). |
| `packages/default.nix` attrs | `packages/default.nix` | Hand-maintained local package registry. |

## LAYOUT RULES

- One baseline: `common` (NixOS and HM) holds everything every machine gets, gated on `sgiath.enable`.
- Hardware is one-of: `sgiath.hardware.gpu`/`boot` are enums, `razer` and `dgx-spark` toggles; pick values, never stack modules. `boot.kernelPackages` is set per host in `systems/<arch>/<host>/hardware.nix` (the DGX Spark module sets it for `juno<N>`); `common/` never picks a kernel.
- Shared modules must evaluate on `aarch64-linux` too: CPU/GPU-vendor modules (`zenpower`) belong in the host's `hardware.nix`; x86-only variants (ROCm, x86 binary blobs) are gated on `pkgs.stdenv.hostPlatform.isx86_64` or the desktop role.
- Roles are additive: `desktop`, `laptop`, `server`, `gaming` under `sgiath.roles.<role>.enable`; a host enables any combination.
- Services hook `services.<name>.enable` uniformly, whether the option is upstream or declared locally in `modules/nixos/services/<name>.nix`.
- Sites are nginx vhosts under `sgiath.sites.<name>.enable`, one file per site in `modules/nixos/sites/`.
- NixOS roles push the matching HM roles via `home-manager.users.sgiath.sgiath.roles.<role>.enable`; homes never set roles themselves.
- Snowfall imports every `modules/<class>/<dir>/default.nix`: exactly one `default.nix` per module directory, none in subdirectories; parents import plain-named `*.nix` files explicitly. Gate with `lib.mkIf`, never by import selection.
- Snowfall rewrites `pkgs` and `lib` for every discovered `<dir>/default.nix` (its channel `pkgs` lacks module-provided `nixpkgs.overlays`, e.g. Stylix's). `default.nix` therefore holds only option declarations, `imports`, and cross-layer option coupling; anything touching `pkgs` lives in a sibling file (`role.nix`, `base.nix`, `<feature>.nix`).

## CONVENTIONS

- Snowfall discovers `systems`, `homes`, `modules`, `packages`, `overlays`, `shells`; do not add manual output lists unless replacing Snowfall behavior.
- Modules use `options.<scope>.enable = lib.mkEnableOption ...` plus `config = lib.mkIf config.<scope>.enable ...`.
- Main NixOS/Home Manager state versions are `23.11`; do not bump casually.
- Secrets are SOPS-encrypted in `secrets/` and decrypted at activation using host SSH keys. Use `sops.secrets` with native runtime credential files; never evaluate plaintext credentials into Nix/store files.
- New files must be `git add`ed before Nix flake evaluation can see them.
- Format Nix with `nixfmt`; use `nix develop` for `nixd`, `nil`, `shfmt`, `prettier`, and update helpers.
- Do not evaluate Home Manager outputs directly; validate homes as part of the full NixOS system evaluation/build. The Stylix HM module is imported unconditionally from `flake.nix` (`homeManagerIntegration.autoImport = false`), so `stylix.targets.*` exist on headless hosts while Stylix itself is only enabled by the desktop role.

## ANTI-PATTERNS

- Never delete the `result` symlink; leave it for the user.
- Do not use `nix-shell` shebangs in new update scripts; add missing tools to `shells/default/default.nix`.
- Do not compute hashes before detecting that an updater's version actually changed.
- Do not copy `packages/relay-tester/update.sh`'s `nix-shell` lockfile step into new scripts; treat it as legacy.
- Do not reintroduce git-crypt, plaintext secret files, or secret values in Nix options/derivations. Ceres's private build-signing key must never be distributed to Vesta.
- Do not gate shared modules on `networking.hostName`; host-only config belongs in `systems/.../<host>/`.
- Destructive git ops are forbidden unless explicit: no reset, clean, restore, force-push.

## COMMANDS

```bash
nix develop
nixfmt <file.nix>
./scripts/update-inputs.sh
nix flake update
nix build '.#<package>'
nix build '.#install-isoConfigurations.live'
nixos-rebuild switch --sudo --flake .
nixos-rebuild switch --sudo --flake '.#ceres'
update --vesta
update --juno1
```

## INSTALLER

- Live image: `systems/x86_64-install-iso/live/default.nix`; commands: `packages/burn-iso/default.nix` and `packages/live-install/default.nix`.
- Run `nix run .#burn-iso -- /dev/sdX` from `~/nixos`. It builds the live ISO from `~/nixos`, bakes the configuration, overwrites the whole USB device, and exports the running user's GPG secret keys/ownertrust directly onto a `SGIATH-KEYS` FAT partition. Keys must never enter Nix or the store; FAT is not encryption. `--iso PATH` reuses an image; `--no-keys` omits the key partition/export.
- Boot auto-logs in as `sgiath`; run `live-install <host>` for `ceres`, `pallas`, or `vesta`. It imports the USB keys, copies the baked repository to `~/nixos`, and wipes the host's configured disks through disko after confirmation. `--keep-disks` skips disko and requires target filesystems already mounted under `/mnt`.
- Inspect the host disk/filesystem configuration before installation. A whole-disk disko wipe on Pallas destroys Windows dual boot; preserve it by adapting the configuration and using existing Linux/boot mounts with `live-install --keep-disks pallas`.
- For a new host SSH recipient, update `.sops.yaml` and applicable creation rules, run `sops updatekeys` on each applicable secrets file, then rerun `sudo nixos-install --flake "$HOME/nixos#<host>" --no-root-passwd` before reboot. Copy the updated checkout to `/mnt/home/sgiath/nixos` and preserve `sgiath:users` ownership. Merely copying ciphertext does not update the installed system; never rerun destructive disko for this step.
- DGX Spark (`juno<N>`): the x86 live ISO cannot boot it; full procedure, unverified assumptions (RJ45 name `enP7s7`, `/dev/nvme0n1`) and post-boot checklist are in `systems/aarch64-linux/juno1/HANDOFF.md`. Adding `juno2`+ means copying `systems/aarch64-linux/juno1/` and `homes/aarch64-linux/sgiath@juno1/`, changing hostname, `192.168.1.1<N>`/`fd39:f21:ea9::1<N>`, and the `common/networking.nix` hosts entry.

## NOTES

- No in-repo CI or NixOS VM test suite. Validate homes through full NixOS builds.
- Custom user commands `update` and `clear-cache` are packages in `packages/`; `update` commits and pushes before rebuilding (`--no-commit` skips that), `update --vesta` builds/signs on Ceres and pushes over SSH, and `update --juno<N>` evaluates locally but builds and switches on the Spark itself (`--build-host`/`--target-host sgiath@juno<N>.sgiath`, `--no-reexec`).
- `clear-cache` runs Nix GC, Docker prune, and journal vacuum; treat as destructive maintenance.
- `scripts/update-inputs.sh` bumps release-pinned flake inputs and runs `packages/*/update.sh`.
- `scripts/nebula-sign.sh <host> <ipv4> <ipv6> [groups]` signs a v2 Nebula host cert with the CA in `secrets/nebula-ca.yaml` and stores it in `secrets/nebula.yaml`; then add the peer to `modules/nixos/common/nebula.nix`. The CA (`nebula-cert ca -name sgiath -duration 87600h`) expires 2036-09; host certs inherit that expiry. Nebula's firewall allows everything between certificate holders, so services bound to `nebula.sgiath` need no auth of their own; the router forwards UDP 4242 to vesta.
- `scripts/nebula-mobile.sh <peer> [out]` renders a self-contained Mobile Nebula site YAML (inline CA/cert/key, lighthouse, relay, Pi-hole over the tunnel as DNS) for a non-NixOS peer in the `peers` table (`phone` = `10.42.0.20`; devices start at `.20`), signing it with group `mobile` on first use. Output defaults to `$XDG_RUNTIME_DIR`; it holds the private key, so import via "Add site > From file" and delete it.
- `dnd5etools` has a separate image hash updater; package `update.sh` alone is incomplete if image assets changed.
