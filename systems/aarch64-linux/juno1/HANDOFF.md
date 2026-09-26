# juno1 (NVIDIA DGX Spark) — install handoff

Written 2026-09-14, before the hardware existed. Pick up here when the Spark
arrives. Everything below was evaluated (`nix eval` of the toplevel on x86)
but never built or booted on real hardware.

## Where things are

| What | Where |
| --- | --- |
| Branch | `feat/juno-dgx-spark` (worktree `~/nixos.feat-juno-dgx-spark`); not merged, not pushed. Merge to master first (`wt merge`), or rebase if master moved. |
| Host config | `systems/aarch64-linux/juno1/{default,hardware,disko}.nix` |
| Home config | `homes/aarch64-linux/sgiath@juno1/default.nix` (empty; roles come from NixOS) |
| Platform module | `modules/nixos/hardware/dgx-spark.nix` behind `sgiath.hardware.dgx-spark.enable` |
| Upstream module | flake input `dgx-spark` = `github:graham33/nixos-dgx-spark` (locked 2026-08-25, `43fff730`), wired in `systems.modules.nixos`; nixpkgs/disko follow ours |
| Deploy from Ceres | `update --juno1` (`packages/update/default.nix`, `deployJuno`) |
| LAN identity | `192.168.1.11` / `fd39:f21:ea9::11`, `juno1.sgiath` in `modules/nixos/common/networking.nix` |

Design decisions already made (don't re-litigate without reason):

- Name `juno<N>`: Juno is asteroid 3, the missing one of Ceres/Pallas/Vesta. Numbered from the start.
- No `roles.server` (nginx/minecraft/Ceres-cache trust are irrelevant); just `sgiath.enable` + `hardware.dgx-spark.enable`.
- Podman (upstream, with docker socket compat), not `virtualisation.docker`.
- nix-daemon `MemoryMax` raised to 96G (128 GB unified memory; the common 24G cap would kill kernel/CUDA builds).
- `cudaCapabilities` left at upstream `["12.0" "12.1"]` — CUDA-dependent packages build from source instead of hitting the Flox cache. Flip to `[ ]` in `hardware/dgx-spark.nix` if the first build is unbearable.
- Kernel is owned by the upstream module; hosts never set `boot.kernelPackages` on juno.

## Assumptions to verify on the real machine

1. **RJ45 interface name `enP7s7`** (Realtek RTL8127, driver `r8127`). Taken from a forum `lshw` of a DGX Spark; the NVIDIA kernel should name it the same. Check with `ip -br link` / `lshw -class network -short` from the live USB. If it differs, fix the `interfaces` key in `hardware.nix`. DHCP stays on as a fallback so a wrong name is not a brick.
2. **NVMe is `/dev/nvme0n1`** (`disko.nix`). `lsblk` before running disko.
3. **Upstream input still evaluates against our nixpkgs**: run `nix flake update dgx-spark` and `nix eval --raw .#nixosConfigurations.juno1.config.system.build.toplevel.drvPath` from Ceres before installing. Their CI tracks nixos-unstable weekly, so the driver/kernel pairing (595.x on 6.17.13 as of writing) may have moved.
4. **aarch64 builds of the HM closure** were never run: oh-my-pi, hermes-agent, opencode, herdr, crit, zed remote server, llm-agents.* all evaluate but may fail to build. Expect to gate a few more things on `isx86_64` in `modules/home/`.

## Before touching NixOS (on DGX OS)

Factory firmware only boots DGX OS (graham33 issue #32).

```bash
sudo fwupdmgr refresh && sudo fwupdmgr get-updates && sudo fwupdmgr update
```

Then in the BIOS: disable Secure Boot, allow USB boot. Note the MAC of the RJ45 port if you want a DHCP reservation on the router.

## Install media

The repo's own live ISO is x86_64 and cannot boot the Spark. Use graham33's
aarch64 USB image. Ceres has no `boot.binfmt.emulatedSystems`, so build it
purely from substitutes (their CI pushes packages, including the kernel, to
cachix):

```bash
nix build 'github:graham33/nixos-dgx-spark#usb-image' --system aarch64-linux --max-jobs 0 \
  --extra-substituters https://graham33.cachix.org \
  --extra-trusted-public-keys graham33.cachix.org-1:DqH72VpwSrACa3+L9eqh4bixjWx9IQUaxQtRh4gtkX8=
sudo dd if=$(echo result/iso/*.iso) of=/dev/sdX bs=1M status=progress && sync
```

If `--max-jobs 0` fails (cache miss), either add
`boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` to ceres temporarily, or
build the image on any aarch64 box. Do not try to `nix build` juno1's own
toplevel on Ceres — the NVIDIA kernel is not in any cache for our nixpkgs pin.

## Install (on the Spark, booted from USB)

```bash
# network: DHCP should be up; otherwise `ip a`, `nmcli`
git clone https://github.com/sgiath/nixos-config ~/nixos && cd ~/nixos

# verify assumptions 1 and 2, edit systems/aarch64-linux/juno1/{hardware,disko}.nix if needed, git add -A

sudo disko --mode destroy,format,mount --yes-wipe-all-disks --flake .#juno1
sudo nixos-install --flake .#juno1 --no-root-passwd     # builds the NVIDIA kernel: long
```

`nixos-install` runs as root on the live system; the 24G daemon cap does not
apply there. If it OOMs on CUDA packages, `--max-jobs 4 --cores 8`.

### SOPS recipient (secrets will not decrypt until this is done)

```bash
sudo ssh-keygen -q -t ed25519 -N "" -C root@juno1 -f /mnt/etc/ssh/ssh_host_ed25519_key   # if nixos-install did not create it
sudo cat /mnt/etc/ssh/ssh_host_ed25519_key.pub | nix run nixpkgs#ssh-to-age
```

On Ceres (needs the GPG key): add `- &juno1 age1...` to `.sops.yaml` `keys`,
add `*juno1` to the age list of the catch-all rule
`secrets/[^/]+\.(yaml|json|env|ini)$` (not to `ceres-signing.yaml` or
`vesta.yaml`), then `sops updatekeys -y secrets/secrets.yaml secrets/nebula.yaml`,
commit, push.
Back on the Spark: `git pull`, rerun `nixos-install` (fast, only the secrets
changed), then:

```bash
sudo mkdir -p /mnt/home/sgiath && sudo cp -a ~/nixos /mnt/home/sgiath/nixos
sudo nixos-enter --root /mnt -c 'chown -R sgiath:users /home/sgiath/nixos'
reboot
```

## Post-boot checklist

```bash
ssh sgiath@juno1.sgiath            # from ceres; key auth from account.nix
uname -r                           # 6.17.13-nvidia
nvidia-smi && nvtop                # GB10 visible, driver loaded
ip -br a                           # enP7s7 192.168.1.11/24 + fd39:f21:ea9::11
systemctl --failed                 # expect nothing; sops-install-secrets if the recipient step was skipped
ls /run/secrets                    # github_token, cliproxy_api_key, nebula-{ca,cert,key}
ping -c1 vesta.nebula.sgiath.dev   # 10.42.0.2 / fd51:da00:4788::2 over nebula.sgiath; lighthouse is nebula.sgiath.dev:4242
podman run --rm --device nvidia.com/gpu=all nvcr.io/nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi
curl -s localhost:11000 | head     # DGX Dashboard
update                             # local rebuild path
```

Then from Ceres: `update --juno1` (evaluates locally, builds + switches on the
Spark over SSH with `--no-reexec`).

## Adding juno2..4

Copy `systems/aarch64-linux/juno1/` and `homes/aarch64-linux/sgiath@juno1/`,
change hostname, `192.168.1.1<N>` / `fd39:f21:ea9::1<N>`, add the hosts entry
in `common/networking.nix`, sign a Nebula cert (`scripts/nebula-sign.sh juno<N>
10.42.0.1<N> fd51:da00:4788::1<N> compute` and add the peer in `common/nebula.nix`), and repeat the
SOPS recipient step. `update --juno<N>`
already accepts any single digit. The ConnectX-7 QSFP ports (`enp1s0f0np0`,
`enp1s0f1np1`; ignore the `enP2p…` twins) are unconfigured — wire them with
static `192.168.100.x/24` addresses when the second Spark arrives (see
upstream `playbooks/connect-two-sparks`, `nccl-two-sparks`).
