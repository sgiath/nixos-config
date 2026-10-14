# NixOS configs

## Install

From the checkout at `~/nixos`, write an installer USB (replace `/dev/sdX`
with the whole USB device, not a partition; all its contents are overwritten):

```bash
cd ~/nixos
nix run .#burn-iso -- /dev/sdX
```

This builds `install-isoConfigurations.live` with a baked snapshot of this
configuration, writes the ISO, and appends a `SGIATH-KEYS` FAT partition. GPG
secret keys and ownertrust are exported directly from your running user
keyring onto that partition, never through Nix or the store. Protect the USB
as private-key material; the FAT filesystem is not encrypted. Use
`--iso /path/to/image.iso` to reuse an existing image or `--no-keys` to write
only the ISO. Bird is vendored in `vendor/bird`, removing the unavailable
upstream and machine-local `bird-src` input dependency.

Boot the USB; the console automatically logs in as `sgiath`. Select `ceres`,
`pallas`, or `vesta`:

```bash
live-install ceres
```

The installer imports keys from `SGIATH-KEYS`, copies the baked configuration
to `~/nixos`, and installs the selected host. **By default, confirmation wipes
every disk in that host's disko configuration.** Inspect the host layout and
`lsblk` output first. In particular, a whole-disk disko install on **Pallas
destroys its Windows dual boot**. To preserve Windows or another existing
layout, inspect and adapt the host filesystem configuration, mount the target
Linux filesystems (including the boot filesystem) under `/mnt`, then use:

```bash
live-install --keep-disks pallas
```

`--keep-disks` skips disko; it does not prepare or validate the existing layout.

**Before rebooting**, if the installed SSH host key has a new SOPS recipient,
add the printed recipient to `.sops.yaml` and the applicable creation rules.
Re-encrypt each applicable secrets file with `sops updatekeys`, then rerun
`nixos-install` so the installed system contains the updated ciphertext:

```bash
cd ~/nixos
# After editing .sops.yaml; repeat for each applicable secrets file:
sops updatekeys -y secrets/secrets.yaml
# Replace ceres with the selected host:
sudo nixos-install --flake "$HOME/nixos#ceres" --no-root-passwd
sudo cp -a ~/nixos/. /mnt/home/sgiath/nixos/
sudo nixos-enter --root /mnt -c 'chown -R sgiath:users /home/sgiath/nixos'
reboot
```

Copying the edited checkout alone does not update the installed system. Do not
rerun the default destructive `live-install` to apply the recipient change.

## Usage

```bash
# update release pinned flake inputs, packages and the Executor image
./scripts/update-inputs.sh

# update branch inputs
nix flake update

# switch current system
update

# switch server
update --vesta
```

## Agent session archive

Every agent session from every host is kept forever in ClickHouse on Vesta
(`services.agent-archive`; the host side is `modules/home/agents/archive.nix`).
Why it is built this way is in
[the decision note](.agents/notes/implemented/architecture/2026-10-14-agent-session-archive.md).

- **Session records.** The hourly `agent-archive` user timer on every host with
  agents ships each store listed in `SOURCES`
  (`modules/home/agents/archive/ship.py`) verbatim into `archive.raw`. It
  keeps no local state and catches up after time offline.
- **Telemetry.** Claude Code and Codex send OpenTelemetry to the `otel-agent`
  user service on `127.0.0.1:4318`, which forwards it from a disk queue to
  database `otel`.
- **Analysis tables.** Database `agents` (`requests`, `tool_calls`, `commands`,
  `sessions`, `tool_timing`, `opencode_recovered_sessions`) is rebuilt from
  `archive.raw` and `otel` every hour, and recreated when its SQL in
  `modules/nixos/services/agent-archive/` changes.
- **Backups.** A daily Parquet file per ingest month of `archive.raw` in
  `/var/backup/agent-archive` on Vesta's root disk. Restore one with
  `clickhouse-client --port 9001 --user archive --query 'INSERT INTO archive.raw FORMAT Parquet' < raw-YYYYMM.parquet`.

Query it over Nebula; the `default` user is read-only:

```bash
curl -s https://clickhouse.sgiath.dev --data \
  "SELECT tool, count() FROM agents.requests GROUP BY tool FORMAT PrettyCompact"
```

The Hermes migration copy on Vesta is readable only by root; archive it once
after deploying with `sudo env HOME=/nonexistent ~/.nix-profile/bin/agent-archive-ship`
(sudo drops your profile from `PATH`).

### Adding an agent harness

The daily `agent-archive-discover` check on every host fails and posts to the
ntfy topic `agent-archive` (`https://ntfy.sgiath.dev/agent-archive`) when it
finds a session store that is neither shipped nor ignored. When adding a
harness, or a new profile of one:

1. Add its session store to `SOURCES` in `ship.py` (`Jsonl`, `Files` or
   `Sqlite`; never credential tables), or to `IGNORED` with the reason.
2. If it records requests or tool calls, add
   `modules/nixos/services/agent-archive/<tool>.sql` with `<tool>_requests` and
   `<tool>_tool_calls` views, list it in `derivedSql`, add it to the unions in
   `tables.sql` (and its shell tool to the `commands` filter), and check the
   counts against the store itself.
3. If it exports OpenTelemetry, point it at `http://127.0.0.1:4318`.

## Upstream workarounds

[UPSTREAM-WORKAROUNDS.md](UPSTREAM-WORKAROUNDS.md) tracks local patches, forks,
exceptional pins, vendoring, compatibility adaptations, and security exceptions
in one place, including upstream evidence and the checks required before removal.
Run `/skill:review-upstream-workarounds` to review them manually using the
[project skill](.omp/skills/review-upstream-workarounds/SKILL.md). No audit runs
automatically at session startup.

## Desktop graphics

Desktop hosts use 64-bit Mesa, and 32-bit Mesa on x86_64, from Hyprland's
pinned nixpkgs input. Keep these drivers aligned with the upstream compositor:
newer system Mesa can require glibc symbols its pinned Hyprland cannot load,
causing startup to fail with `Cannot open backend: no allocator available`.

## Secrets

Secrets are SOPS-encrypted under `secrets/`. Nix evaluation and builds need only
ciphertext; sops-nix decrypts on the target using its SSH Ed25519 host key.
The administrator GPG key can edit all files:

```bash
nix develop -c sops secrets/secrets.yaml
nix develop -c sops secrets/vesta.yaml
```

`secrets.yaml` contains shared/application credentials. `vesta.yaml` contains
Hermes and its Bird credentials and the T3 Code tokens; it is encrypted only
for Vesta and the administrator. `ceres-signing.yaml` contains the build-signing
private key and is encrypted only for Ceres and the administrator. Public keys
are stored unencrypted: the signing key in `secrets/ceres-cache.pub`.

The configured host recipients are Ceres and Vesta. Before deploying another
host or replacing a host's SSH key, add its `ssh-to-age` public recipient to
`.sops.yaml` and run `sops updatekeys` on the relevant files. Keep an offline
backup of the administrator encryption key.

User API credentials are readable only by `sgiath` and loaded into that user's
shell sessions at runtime. `with-api-keys COMMAND` supplies them to commands
started outside a login shell. Nix's GitHub token is included from a protected
runtime file in the user's Nix configuration, not the system-wide `nix.conf`.
Daemon services receive only their own credential files.

Do not put plaintext secrets in the repository, Nix options, derivation
arguments, or generated store files. Git-crypt is no longer used.

## Signed server deployment

After integrating these changes, activate Ceres first to install its signing
key and updated deployment commands:

```bash
nixos-rebuild switch --sudo --flake '.#ceres'
update --vesta
```

Both `update --vesta` build on Ceres, sign the exact
selected system closure, and pass it to `nixos-rebuild --store-path` for SSH
transfer and activation. Neither command changes the existing `result` link.
Vesta trusts Ceres's public key; it never receives the private key. Signature
checks remain enabled, including for downloaded packages. Existing flake
caches remain explicitly allowed for ordinary, non-trusted Nix users.

Factorio uses nixpkgs' standard authenticated downloader. On gaming hosts, SOPS
renders a root-only environment file containing `NIX_FACTORIO_USERNAME` and
`NIX_FACTORIO_TOKEN` for `nix-daemon`; token changes restart the daemon. Once
activated, normal rebuilds download and verify the pinned Space Age archive
automatically, without a separate fetch command or credentials in the store.
For the initial switch from the manual-fetch configuration, the target archive
must already be in the store because the running daemon does not yet have this
environment.

Removing plaintext from the current configuration does not remove it from
old store paths, generations, backups, or previously copied sources. Rotate
the affected credentials after activation; retain recovery generations until
the migrated services have been verified.
