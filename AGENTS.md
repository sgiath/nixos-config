# PROJECT KNOWLEDGE BASE

**Generated:** 2026-06-16
**Commit:** 8380fbec
**Branch:** master

## OVERVIEW

Personal NixOS/Home Manager configuration built with Snowfall Lib namespace `sgiath`. Hosts: `ceres` daily AMD desktop, `pallas` notebook, `vesta` home server, `juno<N>` NVIDIA DGX Spark compute nodes (aarch64, headless; `juno1` first), `hygiea` Oracle Cloud VM (aarch64, no `sgiath.enable` baseline) that keeps the overlay, DNS and the offsite backup target up while Vesta is down.

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
modules/home/agents/              # agent tooling and services (t3code, auto-review, ...)
modules/home/work/                # sgiath.work.{crazyegg,remote}.enable
themes/                           # base16 schemes shared by NixOS and HM stylix
secrets/                          # SOPS files plus public keys (ceres-cache.pub signing key); nebula.yaml (host certs), nebula-ca.yaml (CA key, PGP-only); hygiea.yaml (Hygiea only) and ceres.yaml (Ceres only) keep secrets away from hosts that must not read them
scripts/                          # update-inputs.sh, nebula-sign.sh, nebula-mobile.sh, nebula-jetkvm.sh, link-check.sh
packages/                         # custom packages, update/clear-cache commands, updater scripts
checks/                           # flake checks (Snowfall checks/<name>/default.nix); skill-references runs check-skill-references.py; drive-plan-status runs drive's plan-status tests; shell-safety runs shellcheck with masked-return checks on every tracked *.sh with a shebang
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
| Agent notes | `.agents/notes/` | Proposals and decision rationale; lifecycle and format in its `README.md`. |

## CODE MAP

| Symbol/Field | Location | Role |
| --- | --- | --- |
| `inputs` | `flake.nix` | External flake inputs; Bird uses `vendor/bird` instead of the unavailable upstream/local absolute `bird-src` input. |
| `lib.mkFlake` | `flake.nix` | Snowfall Lib output generation; no manual `nixosConfigurations`. |
| `channels-config` | `flake.nix` | `allowUnfree`, ROCm enabled, CUDA disabled. |
| `systems.modules.nixos` | `flake.nix` | External NixOS modules exposed to all hosts. |
| `homes.modules` | `flake.nix` | External Home Manager modules exposed to all homes. |
| `sgiath.enable` | `modules/nixos/common/default.nix` | Main shared system gate; pushes HM `sgiath.enable` + `roles.terminal`. |
| `sgiath.nebula.{domain,peers}` / `services.nebula.networks.sgiath` | `modules/nixos/common/nebula.nix` | Dual-stack overlay `10.42.0.0/24` + `fd51:da00:4788::/64` on every host (v2 certs). Read-only `peers` table (certificate name → `ip4`/`ip6`, `trusted`, `lighthouse`) picks `<host>_cert`/`<host>_key` from `secrets/nebula.yaml` and feeds `<host>.nebula.sgiath.dev` A/AAAA into `networking.hosts` and A only into Pi-hole (`services/pi-hole.nix`, `services.pihole-ftl.settings.dns.hosts`). Nebula inbound allows only `trusted` peers by certificate name; untrusted ones (JetKVMs) are reachable because the firewall is stateful. A peer with a numeric `lighthouse` endpoint (Vesta: `sgiath.publicIPv4:4242`; Hygiea: its OCI public IP) is lighthouse and relay; every other peer, the phone and the JetKVMs included, registers with and advertises all of them (no DNS needed to bootstrap). Lighthouses may also ping every peer (Hygiea's monitoring). `sgiath.nebula.enable` defaults to `sgiath.enable`; Hygiea sets it alone with its own `secretsFile`. Non-laptop hosts resolve through `sgiath.nebula.resolvers` (Pi-hole on Vesta `10.42.0.2`, then Hygiea `10.42.0.3`), then `1.1.1.1`. |
| Hygiea host | `systems/aarch64-linux/hygiea/` | Minimal NixOS on OCI A1 (Frankfurt), untrusted peer: lighthouse/relay, a second Pi-hole (`services.pi-hole.enable`, overlay only, no vhost records), append-only restic REST server for Vesta (`backup.nix`, user `vesta`, 140 GB cap; Ceres prunes over SFTP as user `restic`), Gatus pinging home with alerts to a secret ntfy.sh topic (`gatus_env` in `secrets/hygiea.yaml`). Public firewall: SSH, UDP 4242, ICMP. `INSTALL.md` is the (re)install runbook. |
| Offsite backup | `systems/x86_64-linux/vesta/offsite-backup.nix`, `systems/x86_64-linux/ceres/offsite-prune.nix` | Restic from Vesta to Hygiea (no prune: append-only); SQLite databases copied with `.backup`, Continuwuity stopped for a copy, live files excluded. Timer off until Vesta's NIC loss is fixed (`scripts/link-check.sh`). Ceres runs unlock, forget (`--keep-within 30d --keep-monthly 12`, refused while a snapshot is dated in the future), prune and a 5% check weekly; the repository password is also in `secrets/ceres.yaml` for restores. |
| Vesta alerts, Hygiea watchdog | `systems/x86_64-linux/vesta/{notify,hygiea-watchdog}.nix` | `notify-failure@%n` posts a unit's last log lines to the local ntfy topic `infra`. `hygiea-watchdog` pings Hygiea every 15 min and starts it through the OCI API (user `hygiea-watchdog`, key `hygiea_oci_key`) when Oracle stopped it. |
| `sgiath.publicIPv4` | `modules/nixos/common/default.nix` | Read-only public IPv4 of the router in front of Vesta; the one place to change after a move. Feeds the Nebula lighthouse endpoint and coturn/LiveKit advertised addresses. Public DNS records and router port forwards are updated by hand. |
| `sgiath.hardware.*` | `modules/nixos/hardware/default.nix` | `gpu` (`null`/`amd`/`nvidia`), `boot` (`uefi`/`legacy`), `razer.enable`, `dgx-spark.enable` (wraps `inputs.dgx-spark` module: NVIDIA 6.17 kernel, open driver, CUDA, podman, ConnectX-7). |
| `sgiath.roles.desktop.enable` | `modules/nixos/desktop/default.nix` | Wayland, audio, bluetooth, printing, Stylix; pushes HM `roles.desktop`. |
| `sgiath.roles.laptop.enable` | `modules/nixos/laptop/default.nix` | NetworkManager + public DNS `resolv.conf`. |
| `sgiath.roles.server.enable` | `modules/nixos/server/default.nix` | Main server-module gate; nginx, minecraft, trusts `secrets/ceres-cache.pub`. |
| `sgiath.roles.gaming.enable` | `modules/nixos/gaming/default.nix` (body in `role.nix`) | Steam/wine/gamescope/gamemode, factorio token; pushes HM `roles.gaming`. |
| `sgiath.sites.<name>.enable` | `modules/nixos/sites/default.nix` | nginx vhosts: `sinai-camp`, `nas`, `eve`, `ai`. `sgiath.dev` itself (site, Matrix/Nostr well-known, WKD) is Cloudflare Workers static assets deployed from the `sgiath.dev` repo, not Vesta. |
| `services.<name>.enable` | `modules/nixos/services/<name>.nix` | Local services (upstream option or declared there). |
| `services.agent-archive.enable` | `modules/nixos/services/agent-archive.nix` (+ `agent-archive/*.sql`) | ClickHouse on Vesta (`/data/clickhouse`, `clickhouse.sgiath.dev`, Nebula only; `default` read-only, `archive` writes). `archive.raw` holds every agent session record verbatim and is never dropped; database `agents` (`requests`, `tool_calls`, `commands`, `sessions`) is rebuilt from it by hourly refreshable views and dropped/recreated when the SQL changes. Daily Parquet copy per ingest month in `/var/backup/agent-archive`. With `services.grafana` on, it provisions the ClickHouse data source and the `agent-archive/dashboards/*.json` dashboards (read-only; replace a file with the exported JSON model to change one). An OpenTelemetry Collector (`otel.sgiath.dev` → :4319) writes Claude Code/Codex telemetry into database `otel` (no TTL, disk queue); `agents.*_timing` views join it to requests and tool calls. `archive.cliproxy` (never dropped, in the Parquet backup) holds CLIProxyAPI usage metadata from `cliproxy-usage`. |
| `services.cliproxyapi.enable` | `modules/nixos/services/cliproxyapi.nix` | CLIProxyAPI on Vesta via the nixpkgs module with the llm-agents package, at `https://cliproxy.sgiath.dev` (Nebula only; OpenAI base `/v1`). Clients use the shared `CLIPROXY_API_KEY`; the management panel (`/management.html`) uses sops `cliproxyapi_management`. OAuth logins live in `/data/cliproxyapi`; API-key upstreams (OpenCode Go; key in `secrets/vesta.yaml`) are listed in the module with their models. `routing.force-model-prefix` keeps work accounts apart: the Remote Claude login (auth-file `"prefix": "remote"`, set via `PATCH /v8/management/credentials/fields`) serves only `remote/<model>`, OpenCode Go only `opencode-go/<model>`, and bare names reach only personal accounts; `config.yaml` is regenerated each start, so panel config edits do not survive a restart. Log in from the panel (paste the failed `localhost` redirect URL) or `sudo -u cliproxyapi cli-proxy-api -config /var/lib/cliproxyapi/config.yaml -no-browser -<provider>-login`. Usage statistics are on: `cliproxy-usage` (`services/cliproxyapi/usage.py`) pops the in-memory usage queue every second with the management key and writes allowlisted metadata (no keys, bodies or headers) into `archive.cliproxy`; `agents.cliproxy_requests` has one typed row per upstream execution (account, requested and executed model, tokens, latency). Records queued when the proxy restarts, or older than the queue's one hour, are lost. |
| `services.grafana.enable` | `modules/nixos/services/grafana.nix` | Grafana on Vesta at `grafana.sgiath.dev` (Nebula only). nginx signs every request in as admin `sgiath` through Grafana's auth proxy (Grafana 13 limits anonymous access to viewers); secret key from `secrets/vesta.yaml`. Data sources and dashboards come from the modules that own the data. |
| HM agent archive shipper | `modules/home/agents/archive.nix`, `archive/ship.py` | Hourly user timer on every agents host; `SOURCES` lists the stores. Cursors live in ClickHouse (no local state); a file generation is its inode. Tests run in the build. Also the `otel-agent` user service: local OTLP collector on `127.0.0.1:4318` that Claude Code (`settings.json` `env`, `claude.nix`) and Codex (`/etc/codex/config.toml`, `modules/nixos/common/codex.nix`) report to; it adds `host.name` and forwards to Vesta from a disk queue, so an unreachable Vesta neither stalls the tools nor drops data. The daily `agent-archive-discover` timer (`ship.py --discover`) fails and posts to ntfy topic `agent-archive` when a session store is neither in `SOURCES` nor `IGNORED`; README "Adding an agent harness" is the checklist. |
| HM `services.auto-review` | `modules/home/agents/auto-review.nix`, `packages/auto-review/` | User service on Ceres: reviews MRs/PRs that request Filip's review (repos in `homes/x86_64-linux/sgiath@ceres/default.nix`, contexts beside it) in full-access T3 threads, posts findings ≥ threshold as line comments, approves only under a repo's `approval = "when_clean"`, settles threads. UI on `127.0.0.1:8787`; UI settings in `$XDG_STATE_HOME/auto-review/overrides.json` override the Nix defaults per field. State is SQLite there; T3 sign-in via pairing-code OAuth, bearer in memory only. Package README is the reference; tests run in the build. |
| HM `sgiath.roles.*` | `modules/home/{terminal,desktop,gaming}/default.nix` | User-side role bodies; set from NixOS, not from homes. |
| HM `sgiath.programs.*` | `modules/home/programs/default.nix` | `audio`, `bitcoin`, `chat`, `editors`, `email`, `browsers` (desktop role); `blender` (per host, Blender Lab MCP for agents). |
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
- Work directly on `master` in `~/nixos`; the global worktree default does not apply here. Other threads may have uncommitted changes in this checkout: commit only your own paths and leave theirs alone.
- Format Nix with `nixfmt`; use `nix develop` for `nixd`, `nil`, `shfmt`, `prettier`, and update helpers.
- Do not evaluate Home Manager outputs directly; validate homes as part of the full NixOS system evaluation/build. The Stylix HM module is imported unconditionally from `flake.nix` (`homeManagerIntegration.autoImport = false`), so `stylix.targets.*` exist on headless hosts while Stylix itself is only enabled by the desktop role.

## ANTI-PATTERNS

- Never delete the `result` symlink; leave it for the user.
- Never replace Home Manager-managed files or symlinks by hand to preview a change (the next switch then fails with "would be clobbered"). Build the change, or say a rebuild is pending.
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
update --refresh           # update-inputs.sh + nix flake update + update
nix flake check
nix build '.#<package>'
nix build '.#install-isoConfigurations.live'
nixos-rebuild switch --sudo --flake .
nixos-rebuild switch --sudo --flake '.#ceres'
update --vesta
update --juno1
update --hygiea
```

## INSTALLER

- Live image: `systems/x86_64-install-iso/live/default.nix`; commands: `packages/burn-iso/default.nix` and `packages/live-install/default.nix`.
- Run `nix run .#burn-iso -- /dev/sdX` from `~/nixos`. It builds the live ISO from `~/nixos`, bakes the configuration, overwrites the whole USB device, and exports the running user's GPG secret keys/ownertrust directly onto a `SGIATH-KEYS` FAT partition. Keys must never enter Nix or the store; FAT is not encryption. `--iso PATH` reuses an image; `--no-keys` omits the key partition/export.
- Boot auto-logs in as `sgiath`; run `live-install <host>` for `ceres`, `pallas`, or `vesta`. It imports the USB keys, copies the baked repository to `~/nixos`, and wipes the host's configured disks through disko after confirmation. `--keep-disks` skips disko and requires target filesystems already mounted under `/mnt`.
- Inspect the host disk/filesystem configuration before installation. A whole-disk disko wipe on Pallas destroys Windows dual boot; preserve it by adapting the configuration and using existing Linux/boot mounts with `live-install --keep-disks pallas`.
- Pallas (Windows dual boot) is reinstalled from Ceres over SSH into the live ISO with `systems/x86_64-linux/pallas/reinstall.sh`; `REINSTALL.md` beside it is the runbook. Its SSH host key is pre-generated on Ceres so secrets decrypt on first boot.
- For a new host SSH recipient, update `.sops.yaml` and applicable creation rules, run `sops updatekeys` on each applicable secrets file, then rerun `sudo nixos-install --flake "$HOME/nixos#<host>" --no-root-passwd` before reboot. Copy the updated checkout to `/mnt/home/sgiath/nixos` and preserve `sgiath:users` ownership. Merely copying ciphertext does not update the installed system; never rerun destructive disko for this step.
- DGX Spark (`juno<N>`): the x86 live ISO cannot boot it; full procedure, unverified assumptions (RJ45 name `enP7s7`, `/dev/nvme0n1`) and post-boot checklist are in `systems/aarch64-linux/juno1/HANDOFF.md`. Adding `juno2`+ means copying `systems/aarch64-linux/juno1/` and `homes/aarch64-linux/sgiath@juno1/`, changing hostname, `192.168.1.1<N>`/`fd39:f21:ea9::1<N>`, and the `common/networking.nix` hosts entry.

## NOTES

- No in-repo CI or NixOS VM test suite. Validate homes through full NixOS builds.
- Custom user commands `update` and `clear-cache` are packages in `packages/`. `update --refresh` (combinable with any target) first runs `scripts/update-inputs.sh` in the dev shell; if it fails, the log is kept in `$XDG_STATE_HOME/update/`, a T3 thread in `~/nixos` is started with its errors (`t3 thread start`, project default model and settings) and nothing else runs; otherwise it runs `nix flake update` in place of the lock step. `update` first runs `nix flake lock` and formats Nix files changed since upstream (including new files) in place, then validates a snapshot of the formatted worktree: every flake check, evaluation of every host, and a build of the target's toplevel (or the ISO). Only then does it commit and push (`--no-commit` skips that) and switch to that exact build; a snapshot of a dirty tree evaluates as `path:`, so its system has no `configurationRevision`. `update --vesta` builds/signs on Ceres and pushes over SSH, and `update --juno<N>`/`update --hygiea` are only evaluated during validation and build and switch on the host itself (`--build-host`/`--target-host`, `--no-reexec`; `juno<N>.sgiath` on the LAN, `hygiea.nebula.sgiath.dev` over Nebula).
- `clear-cache` runs Nix GC, Docker prune, and journal vacuum; treat as destructive maintenance.
- `scripts/update-inputs.sh` bumps release-pinned flake inputs, runs `packages/*/update.sh`, then `scripts/update-executor.sh`, which pins `version` in `modules/nixos/services/executor.nix` to the newest semver tag on `ghcr.io/rhyssullivan/executor-selfhost`. Never switch Executor to `:latest`: an unchanged unit is not restarted on switch, so the image would never refresh. Afterwards it builds every package an updater changed (including packages that read `../<dir>/`) and exits non-zero naming failed `update.sh` scripts and failed builds.
- `scripts/nebula-sign.sh <host> <ipv4> <ipv6> [groups]` signs a v2 Nebula host cert with the CA in `secrets/nebula-ca.yaml` and stores it in `secrets/nebula.yaml`; then add the peer to `modules/nixos/common/nebula.nix`. The CA (`nebula-cert ca -name sgiath -duration 87600h`) expires 2036-09; host certs inherit that expiry. Nebula's inbound firewall on NixOS hosts admits every `trusted` peer, so services bound to `nebula.sgiath` need no auth of their own; the router forwards UDP 4242 to vesta.
- `scripts/nebula-mobile.sh <peer> [out]` renders a self-contained Mobile Nebula site YAML (inline CA/cert/key, lighthouse, relay, Pi-hole over the tunnel as DNS) for a non-NixOS peer in the `peers` table (`phone` = `10.42.0.20`; devices start at `.20`), signing it with group `mobile` on first use. Output defaults to `$XDG_RUNTIME_DIR`; it holds the private key, so import via "Add site > From file" and delete it.
- `scripts/nebula-jetkvm.sh <peer> <lan-address>` installs Nebula on a JetKVM (`kvm-<machine>`, `.21`+, untrusted, group `kvm`) over its Developer Mode SSH: the `nebula-jetkvm` package (static armv7 build of the hosts' Nebula), a config whose inbound admits only `trusted` peers, and `/userdata/init.d/S23nebula`, which the firmware runs at boot and which waits for a default route and a clock past the install time (no RTC: it boots at 1970 and Nebula rejects not-yet-valid certs). Rerun it to update; `/userdata` survives OTA updates but not a factory reset. HTTPS: Vesta issues `<kvm>.nebula.sgiath.dev` per KVM (`systems/x86_64-linux/vesta/jetkvm-tls.nix`, list `kvms`) and `jetkvm-tls.py` installs it through JetKVM's WebRTC `setTLSState` RPC after renewal and daily, only when the served certificate differs (a push replaces any open KVM session); HTTP stays on for recovery. Desktop Chromium has one app launcher per `kvm-*` peer with its own profile and `--webrtc-ip-handling-policy=default_public_and_private_interfaces`, because ungoogled-chromium's default offers no local WebRTC candidates and the KVM video never connects (`modules/home/desktop/chromium.nix`).
- LAN IPv6: PODA gives no prefix delegation (its DHCPv6 server ignores IA_NA/IA_PD), only a static `2a00:ca8:a16:35d4::/64` on the Turris WAN via SLAAC. The Turris odhcpd relays that RA and NDP onto `lan` (`dhcp.wan6` master, `ra`/`ndp` `relay`; DHCPv6 stays `server` for the ULA, RDNSS rewritten to the router ULA). Hosts take the IPv6 default route from RA; never pin a static `defaultGateway6`. The router firewall is the only inbound IPv6 filter, since NixOS firewalls are off.
- `scripts/link-check.sh` (run on Ceres) measures large-packet loss from Vesta to the router, NAS and Hygiea and TCP speed to Cloudflare, with Ceres as control; it fails while Vesta's enp1s0 drops large outbound packets (seen 2026-11-12: ~20% loss, ~1 Mbit/s uploads). Vesta and Ceres cannot reach each other directly on the LAN (ARP fails both ways).
- Pi-hole (`services/pi-hole.nix`) holds Nebula IPv4 records only: every peer, every overlay-only `sgiath.nebula.services` name, and every other SSL nginx vhost on Vesta resolve to `10.42.0.2`/the peer's `10.42.0.x`, so reaching Vesta's vhosts through Pi-hole requires Nebula. No LAN or IPv6 addresses: AAAA for public vhosts forwards upstream (Cloudflare-proxied names return Cloudflare IPv6), and the lighthouse name `nebula.sgiath.dev` resolves upstream to the public IP. A local `dns-rr` HTTPS record replaces Cloudflare's, whose edge hints and ECH config nginx cannot serve; MX/TXT/SRV and apex subdomains still resolve upstream. Public DNS still goes through Cloudflare/the public IP; Pallas uses public DNS and bypasses this. Hygiea's Pi-hole has the same peer and overlay-service records but no vhost records, so public names resolve there consistently from upstream.
- Clients on Vesta's LAN get the Turris (`192.168.1.1` via DHCPv4, its ULA via RA/DHCPv6) as DNS; its kresd forwards everything to Pi-hole (`resolver.common.forward_custom='pihole_…'`) with `ignore_root_key=1`, because kresd DNSSEC validation turns Pi-hole's local `sgiath.dev` records and block answers into SERVFAIL. Pi-hole does the DNSSEC validation and has no rate limit, since every LAN query reaches it from `192.168.1.1`. A router on another LAN cannot reach Pi-hole (it is no Nebula peer), so it resolves on its own; NixOS hosts there bypass it through their `resolv.conf` (Pi-hole over Nebula, then public).
- `dnd5etools` has a separate image hash updater; package `update.sh` alone is incomplete if image assets changed.

## Agent notes

`.agents/notes/` contains durable proposals and decision records. Notes preserve rationale, alternatives, consequences, and required verification; they are not canonical product reference. Follow `.agents/notes/README.md` for lifecycle, classification, format, supersession, and archive rules.

Before implementing anything, search `.agents/notes/proposed/` for a note that covers the work. The commit that implements it also moves the note to `implemented/`, rewritten in the implemented format, with links to it repaired; a partial implementation moves the shipped part and leaves the rest proposed. Never record progress inside a proposed note, and never move a note in a separate follow-up commit.

Before writing or changing canonical docs (`README.md`), read the relevant active Agent Notes and implementation code. If implementation and notes diverge, report the divergence and clarify before documenting behavior.
