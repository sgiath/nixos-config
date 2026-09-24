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
# update release pinned flake inputs and packages
./scripts/update-inputs.sh

# update branch inputs
nix flake update

# switch current system
update

# switch server
update --vesta
```

## Secrets

Secrets are SOPS-encrypted under `secrets/`. Nix evaluation and builds need only
ciphertext; sops-nix decrypts on the target using its SSH Ed25519 host key.
The administrator GPG key can edit all files:

```bash
nix develop -c sops secrets/secrets.yaml
nix develop -c sops secrets/vesta.yaml
```

`secrets.yaml` contains shared/application credentials. `vesta.yaml` contains
Hermes and its Bird credentials and is encrypted only for Vesta and the
administrator. `ceres-signing.yaml` contains the build-signing private key and
is encrypted only for Ceres and the administrator. Only the public signing key
is stored unencrypted, in `secrets/ceres-cache.pub`.

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
