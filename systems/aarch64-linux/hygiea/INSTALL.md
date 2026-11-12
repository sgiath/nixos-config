# Hygiea: (re)install on Oracle Cloud

Hygiea is an Oracle Cloud Always Free VM in the Frankfurt home region
(tenancy home region cannot change). Rebuild it from Ceres with nixos-anywhere
when the instance is lost (e.g. Oracle reclaimed and terminated it).

## Oracle console

- Instance: `VM.Standard.A1.Flex`, 1 OCPU, 6 GB, Canonical Ubuntu (aarch64),
  boot volume 200 GB (the whole free block storage allowance), your SSH key,
  in compartment `hygiea` (the watchdog's permissions are scoped to it).
- VCN security list ingress: TCP 22 and UDP 4242 from `0.0.0.0/0`, **source
  port All**. A source port of 4242 only admits lighthouses.
- A new instance gets a new public IP: put it into `lighthouse` of the `hygiea`
  peer in `modules/nixos/common/nebula.nix`, the instance OCID into
  `systems/x86_64-linux/vesta/hygiea-watchdog.nix`, and redeploy every host,
  rerun `scripts/nebula-jetkvm.sh` for each JetKVM and `scripts/nebula-mobile.sh`
  for the phone.
- Watchdog identity: group `HygieaRestarter`, API user `hygiea-watchdog`
  (key `hygiea_oci_key` in `secrets/vesta.yaml`, fingerprint in the watchdog
  module), root-compartment policy:

  ```
  Allow group HygieaRestarter to read instances in compartment hygiea
  Allow group HygieaRestarter to use instances in compartment hygiea where request.operation='InstanceAction'
  ```

## Host key

`secrets/hygiea.yaml` is encrypted to the age key derived from Hygiea's SSH host
key, so the installed system must get that key. Keep the private key from the
first install, or generate a new one and re-encrypt:

```sh
state=$XDG_RUNTIME_DIR/hygiea-install
install -d -m700 "$state/extra/etc/ssh"
ssh-keygen -t ed25519 -N "" -C root@hygiea -f "$state/extra/etc/ssh/ssh_host_ed25519_key"
nix develop --command ssh-to-age -i "$state/extra/etc/ssh/ssh_host_ed25519_key.pub"
# put the age key into .sops.yaml (&hygiea), then:
nix develop --command sops updatekeys secrets/hygiea.yaml
# and update the public key in systems/x86_64-linux/ceres/offsite-prune.nix
```

## Install

From `~/nixos` on Ceres:

```sh
nix run .#nixosConfigurations.ceres.pkgs.nixos-anywhere -- \
  --flake .#hygiea --target-host ubuntu@<public-ip> --build-on remote \
  --kexec-extra-flags --kexec-syscall --extra-files "$state/extra"
```

- `--kexec-syscall`: Oracle's Ubuntu kernel rejects `kexec_file_load` with
  "Address not available"; the classic syscall works.
- If disko fails with `mkfs.vfat: unable to open /dev/disk/by-partlabel/disk-main-ESP`
  (udev recreates the partition links after partitioning), format by hand in
  the installer and resume:

  ```sh
  ssh root@<public-ip> 'udevadm settle && mkfs.vfat /dev/disk/by-partlabel/disk-main-ESP &&
    mkfs.ext4 -F -q /dev/disk/by-partlabel/disk-main-root &&
    mount /dev/disk/by-partlabel/disk-main-root /mnt && mkdir -p /mnt/boot &&
    mount -o umask=0077 /dev/disk/by-partlabel/disk-main-ESP /mnt/boot'
  nix run .#nixosConfigurations.ceres.pkgs.nixos-anywhere -- \
    --flake .#hygiea --target-host root@<public-ip> --build-on remote \
    --phases install,reboot --extra-files "$state/extra"
  ```

## Afterwards

- `ssh sgiath@hygiea.nebula.sgiath.dev`; `update` deploys it natively like
  `juno<N>` (`update --hygiea`).
- A boot volume enlarged in the console grows into `/` on the next boot.
- The backup repository (`/var/lib/restic/vesta`) starts empty; Vesta's next
  run uploads everything again.
