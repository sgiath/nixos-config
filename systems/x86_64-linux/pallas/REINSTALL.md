# Reinstalling Pallas next to Windows

Replaces whatever Linux is on Pallas (Omarchy) with this NixOS configuration and
keeps Windows. The agent on Ceres runs `reinstall.sh` over SSH into the live ISO;
sgiath does only the steps at the notebook. Run every command from `~/nixos` on Ceres.

## What the script does

- `inspect`: hardware, Secure Boot, partition tables, contents of every EFI
  system partition, firmware boot entries, network.
- `partition <disk> <n>...`: deletes the given partitions and creates, in the
  largest free block, a 1 GiB ESP, a swap partition (`PALLAS_SWAP`, default 16G)
  and a btrfs root with the `root`, `home` and `nix/store` subvolumes Ceres and
  Vesta use. The filesystems get the UUIDs from `hardware.nix`, so the
  configuration needs no change. `mount` mounts what `hardware.nix` declares. It refuses Windows partition types, NTFS and
  BitLocker volumes, and any ESP that contains the Windows boot manager.
- `install`: builds the pallas system from the committed HEAD on Ceres, writes the pre-generated SSH
  host key to the target (so SOPS secrets decrypt on first boot), copies the
  closure (the target downloads public cache paths itself), runs `nixos-install`,
  and copies a clean clone of HEAD to `/home/sgiath/nixos`. A QEMU rehearsal
  took 40 minutes for the first run and 2 minutes for a repeat.
- `verify`: checks the installed system over SSH, pinning the known host key.

NixOS gets its own ESP. Windows keeps its ESP untouched; boot it from the
systemd-boot "Windows 11" entry or the firmware boot menu.

## Prepared on Ceres (done before the session)

- Host key in `$XDG_RUNTIME_DIR/pallas-install/ssh_host_ed25519_key`; its age
  recipient is `&pallas` in `.sops.yaml`, and `secrets/secrets.yaml` and
  `secrets/nebula.yaml` are re-encrypted for it. The directory is tmpfs: if Ceres
  reboots before the install, generate a new key, replace the recipient and run
  `sops updatekeys -y` on both files again.
- Pallas system and live ISO built.

## Runbook

1. **sgiath, in Windows:** save the BitLocker recovery key
   (<https://account.microsoft.com/devices/recoverykey>, or
   `manage-bde -protectors -get C:` in an admin shell). Then suspend BitLocker
   for the next reboots: `manage-bde -protectors -disable C: -RebootCount 3`.
   Changing Secure Boot or the boot order otherwise triggers the recovery screen.
   Copy anything you still need off Omarchy; it will be deleted.
2. **sgiath:** plug a USB stick (4 GB or more; it is overwritten) into Ceres.
3. **Agent:** build the live ISO from HEAD (the checkout may hold other sessions'
   uncommitted edits) and write it without GPG keys, which this flow does not need:
   ```bash
   iso=$(nix build --no-link --print-out-paths "git+file://$PWD?rev=$(git rev-parse HEAD)&lfs=1#install-isoConfigurations.live")
   printf '%s\n' sdX | nix run .#burn-iso -- --no-keys --iso "$iso"/iso/*.iso /dev/sdX
   ```
4. **sgiath, at Pallas:** plug in the stick, power on and press F12 for the boot
   menu (F1 or Del opens the firmware setup). If the stick does not boot, disable
   Secure Boot in the firmware setup. Boot the NixOS live entry.
5. **sgiath:** the console logs in as `sgiath`. Run `nmtui` → "Activate a
   connection" → your Wi-Fi (or plug in Ethernet). Run `ip -br a` and send the
   agent the IPv4 address.
6. **Agent:** `systems/x86_64-linux/pallas/reinstall.sh inspect <ip>`. Report the
   layout and the partitions to delete: every Omarchy partition (Linux
   filesystem, LUKS, swap, and its own ESP if it has one). If Omarchy's boot
   files (Limine, `EFI/Linux`) live on the Windows ESP, list them too.
7. **sgiath:** confirm the partitions to delete.
8. **Agent:** `systems/x86_64-linux/pallas/reinstall.sh partition <ip> /dev/nvmeXn1 <n>...`.
   If Omarchy used the Windows ESP, delete only its own files there (never
   `EFI/Microsoft`, and `EFI/BOOT` only if it holds Limine).
9. **Agent:** `systems/x86_64-linux/pallas/reinstall.sh install <ip>`. Then remove
   Omarchy's firmware boot entry (`sudo efibootmgr -b XXXX -B` over SSH) and check
   that "Linux Boot Manager" comes first in the boot order.
10. **sgiath:** reboot, remove the stick, pick NixOS in systemd-boot, log in and
    connect Wi-Fi with the "Wi-Fi" launcher entry.
11. **Agent:** `systems/x86_64-linux/pallas/reinstall.sh verify pallas.nebula.sgiath.dev`
    (the laptop firewall closes SSH on the LAN; only Nebula gets in): no failed
    units, `/run/secrets` populated, Nebula up, NVIDIA driver loaded. Then
    `rm -rf "$XDG_RUNTIME_DIR/pallas-install"`.
12. **sgiath:** reboot and pick "Windows 11". If that entry fails, pick the "EFI
    Shell" entry instead, run `map -c`, then `ls <handle>:\EFI` for each `HD`
    handle until one lists `Microsoft`; send the agent that handle (it goes into
    `efiDeviceHandle` in `hardware.nix`). Meanwhile Windows boots from the F12
    menu. In Windows, run `manage-bde -protectors -enable C:`.

## Recovery

- Live ISO rebooted: run `inspect` again (new host key and maybe a new IP), then
  `mount`, then `install`.
- `install` failed: fix the cause and run `install` again; it is repeatable.
- `partition` stopped midway: it is not repeatable (it refuses existing
  `pallas-*` labels). Look at `sgdisk -p` and finish by hand.
