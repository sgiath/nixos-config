#!/usr/bin/env bash
# Reinstalls Pallas from Ceres over SSH into the booted live ISO, keeping Windows.
# Run from ~/nixos on Ceres; REINSTALL.md is the runbook.
#
#   reinstall.sh inspect   <host>
#   reinstall.sh partition <host> <disk> <partition-number>...
#   reinstall.sh mount     <host>
#   reinstall.sh install   <host>
#   reinstall.sh verify    <host>
#
# PALLAS_SSH_PORT (default 22) and PALLAS_SWAP (default 16G) adjust the target.
set -euo pipefail

state="${XDG_RUNTIME_DIR:?}/pallas-install"
host_key="$state/ssh_host_ed25519_key"
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
# Only committed work is installed; other sessions may have uncommitted edits in the checkout.
rev=$(git -C "$repo" rev-parse HEAD)
flake="git+file://$repo?rev=$rev#nixosConfigurations.pallas"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ $# -ge 2 ]] || die "usage: $0 inspect|partition|mount|install|verify <host> [args]"
cmd=$1
host=$2
shift 2

ssh_opts=(-o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$state/known_hosts" -p "${PALLAS_SSH_PORT:-22}")

# Runs the bash script on stdin as root on the target, with the given arguments.
remote() {
  # ssh joins its arguments into one string for the remote shell; quote each so newlines survive.
  local cmd
  printf -v cmd '%q ' sudo bash -s -- "$@"
  # shellcheck disable=SC2029 # expanded and quoted here on purpose
  ssh "${ssh_opts[@]}" "sgiath@$host" "$cmd"
}

# Filesystem identifiers come from hardware.nix, so the new filesystems match the built system.
uuid_of() {
  local dev
  dev=$(nix eval --raw "$flake.config.$1")
  echo "${dev#/dev/disk/by-uuid/}"
}

identifiers() {
  root_uuid=$(uuid_of 'fileSystems."/".device')
  esp_uuid=$(uuid_of 'fileSystems."/boot".device')
  swap_uuid=$(nix eval --raw "$flake.config.swapDevices" --apply 'l: (builtins.head l).device')
  swap_uuid=${swap_uuid#/dev/disk/by-uuid/}
}

# Mounts every local filesystem from hardware.nix under /mnt; attribute order puts parents first.
mount_target() {
  identifiers
  local mounts
  # shellcheck disable=SC2016 # Nix expression, not shell
  mounts=$(nix eval --raw "$flake.config.fileSystems" --apply '
    fs: builtins.concatStringsSep "\n" (
      map (mp: let f = fs.${mp}; in "${mp} ${f.device} ${f.fsType} ${builtins.concatStringsSep "," f.options}")
        (builtins.filter (mp: fs.${mp}.fsType != "nfs") (builtins.attrNames fs))
    )')
  remote "$mounts" "$swap_uuid" <<'EOF'
set -euo pipefail
udevadm settle
while read -r mp dev type opts; do
  target=/mnt${mp%/}
  mkdir -p "$target"
  mountpoint -q "$target" || mount -t "$type" -o "$opts" "$dev" "$target"
done <<<"$1"
swapon --show=UUID --noheadings | grep -qx "$2" || swapon "/dev/disk/by-uuid/$2"
findmnt -R /mnt
swapon --show
EOF
}

case "$cmd" in
inspect)
  # The live ISO generates a new host key on every boot.
  install -d -m700 "$state"
  : >"$state/known_hosts"
  remote <<'EOF'
set -u
esp_type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
echo "== machine"
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null
grep -m1 'model name' /proc/cpuinfo
free -h | head -2
lspci -nn | grep -Ei 'vga|3d|display'
echo "== firmware"
[ -d /sys/firmware/efi ] && echo "UEFI" || echo "LEGACY BIOS"
sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | awk '{print $NF}')
echo "SecureBoot=${sb:-unknown}"
echo "== block devices"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,PARTTYPENAME,UUID,MOUNTPOINTS
for d in /sys/block/nvme*n1 /sys/block/sd*; do
  [ -e "$d" ] || continue
  echo "== partition table /dev/${d##*/}"
  sgdisk -p "/dev/${d##*/}"
done
for p in $(lsblk -lnpo NAME,PARTTYPE | awk -v t="$esp_type" 'tolower($2) == t {print $1}'); do
  echo "== EFI system partition $p"
  m=$(mktemp -d)
  mount -o ro "$p" "$m"
  df -h --output=size,used,avail "$m"
  (cd "$m" && find . -maxdepth 3 | sort)
  umount "$m"
  rmdir "$m"
done
echo "== firmware boot entries"
efibootmgr -v
echo "== network"
ip -br addr
EOF
  ;;

partition)
  [[ $# -ge 2 ]] || die "usage: $0 partition <host> <disk> <partition-number>..."
  disk=$1
  shift
  identifiers
  remote "$disk" "${PALLAS_SWAP:-16G}" "$root_uuid" "$esp_uuid" "$swap_uuid" "$@" <<'EOF'
set -euo pipefail
disk=$1 swap=$2 root_uuid=$3 esp_uuid=$4 swap_uuid=$5
shift 5
esp_type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
# Microsoft reserved, Microsoft basic data, Windows recovery.
windows_types=" e3c9e316-0b5c-4db8-817d-f92df00215ae ebd0a0a2-b9e5-4433-87c0-68b6b72699c7 de94bba4-06d1-4d40-a16a-bfd50179d6ac "

[ "$(lsblk -dno TYPE "$disk")" = disk ] || { echo "$disk is not a disk" >&2; exit 1; }
for label in pallas-boot pallas-swap pallas-root; do
  [ ! -e "/dev/disk/by-partlabel/$label" ] || { echo "partition label $label already exists" >&2; exit 1; }
done

parts=()
for n in "$@"; do
  p=$(lsblk -lnpo NAME,PARTN "$disk" | awk -v n="$n" '$2 == n {print $1}')
  [ -n "$p" ] || { echo "no partition $n on $disk" >&2; exit 1; }
  type=$(lsblk -dno PARTTYPE "$p" | tr 'A-F' 'a-f')
  fs=$(blkid -o value -s TYPE "$p" || true)
  case "$windows_types" in *" $type "*) echo "refusing $p: Windows partition type $type" >&2; exit 1 ;; esac
  case "$fs" in ntfs | BitLocker) echo "refusing $p: $fs filesystem" >&2; exit 1 ;; esac
  if [ "$type" = "$esp_type" ]; then
    m=$(mktemp -d)
    mount -o ro "$p" "$m"
    ms=$(find "$m" -maxdepth 2 -iname microsoft | head -1)
    umount "$m"
    rmdir "$m"
    [ -z "$ms" ] || { echo "refusing $p: EFI partition holds the Windows boot manager" >&2; exit 1; }
  fi
  parts+=("$p")
done
for p in "${parts[@]}"; do
  [ -z "$(lsblk -no MOUNTPOINTS "$p" | tr -d '[:space:]')" ] || { echo "$p is mounted" >&2; exit 1; }
done

echo "== before"
sgdisk -p "$disk"
for p in "${parts[@]}"; do wipefs -a "$p"; done
for n in "$@"; do sgdisk -d "$n" "$disk"; done
# Start 0 is the start of the largest free block, end 0 its end.
sgdisk -n 0:0:+1G -t 0:ef00 -c 0:pallas-boot \
  -n "0:0:+$swap" -t 0:8200 -c 0:pallas-swap \
  -n 0:0:0 -t 0:8304 -c 0:pallas-root "$disk"
partprobe "$disk"
udevadm settle
echo "== after"
sgdisk -p "$disk"

boot=/dev/disk/by-partlabel/pallas-boot
wipefs -a "$boot" /dev/disk/by-partlabel/pallas-swap /dev/disk/by-partlabel/pallas-root
mkfs.vfat -F 32 -n NIXBOOT -i "${esp_uuid//-/}" "$boot"
mkswap -L swap -U "$swap_uuid" /dev/disk/by-partlabel/pallas-swap
mkfs.btrfs -q -f -L nixos -U "$root_uuid" /dev/disk/by-partlabel/pallas-root
udevadm settle
# Subvolumes as named in hardware.nix (subvol=/root, /home, /nix/store).
top=$(mktemp -d)
mount /dev/disk/by-partlabel/pallas-root "$top"
mkdir "$top/nix"
btrfs subvolume create "$top/root" "$top/home" "$top/nix/store"
umount "$top"
rmdir "$top"
for id in "$root_uuid" "$esp_uuid" "$swap_uuid"; do
  [ "$(blkid -U "$id" | wc -l)" -eq 1 ] || { echo "UUID $id is not unique" >&2; exit 1; }
done
EOF
  mount_target
  ;;

mount)
  mount_target
  ;;

install)
  [[ -f "$host_key" ]] || die "$host_key missing; generate it and add its recipient to .sops.yaml (REINSTALL.md)"
  recipient=$(nix shell nixpkgs#ssh-to-age -c ssh-to-age <"$host_key.pub")
  git -C "$repo" show "$rev:.sops.yaml" | grep -q "&pallas $recipient" || die "$host_key is not the pallas recipient in .sops.yaml"

  echo "==> Building pallas"
  toplevel=$(nix build --no-link --print-out-paths "$flake.config.system.build.toplevel")
  echo "$toplevel"

  echo "==> Preparing the target"
  remote <<'EOF'
set -euo pipefail
mountpoint -q /mnt && mountpoint -q /mnt/boot || { echo "target is not mounted; run mount" >&2; exit 1; }
install -d -m700 /root/.ssh
install -m600 /etc/ssh/authorized_keys.d/sgiath /root/.ssh/authorized_keys
EOF
  ssh "${ssh_opts[@]}" "sgiath@$host" sudo install -D -m600 /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key <"$host_key"
  ssh "${ssh_opts[@]}" "sgiath@$host" sudo install -D -m644 /dev/stdin /mnt/etc/ssh/ssh_host_ed25519_key.pub <"$host_key.pub"

  echo "==> Copying the closure (the target fetches public cache paths itself)"
  NIX_SSHOPTS="${ssh_opts[*]}" nix copy --no-check-sigs --substitute-on-destination \
    --to "ssh://root@$host?remote-store=/mnt" "$toplevel"

  echo "==> nixos-install"
  remote "$toplevel" <<'EOF'
set -euo pipefail
nixos-install --root /mnt --system "$1" --no-root-passwd --no-channel-copy
EOF

  echo "==> Copying the checkout to /home/sgiath/nixos"
  clone=$(mktemp -d)
  git clone -q "$repo" "$clone"
  git -C "$clone" checkout -q "$rev"
  git -C "$clone" checkout -q -B master
  origin=$(git -C "$repo" remote get-url origin)
  git -C "$clone" remote set-url origin "$origin"
  tar -C "$clone" -cf - . |
    ssh "${ssh_opts[@]}" "sgiath@$host" sudo sh -c "'rm -rf /mnt/home/sgiath/nixos && install -d /mnt/home/sgiath/nixos && tar -C /mnt/home/sgiath/nixos -xf -'"
  rm -rf "$clone"
  remote <<'EOF'
set -euo pipefail
nixos-enter --root /mnt -c 'chown sgiath:users /home/sgiath && chown -R sgiath:users /home/sgiath/nixos' >/dev/null
efibootmgr
EOF
  echo "==> Installed. Reboot the notebook and remove the USB stick."
  ;;

verify)
  # The installed system uses the pre-generated host key, so pin it.
  port=${PALLAS_SSH_PORT:-22}
  name=$host
  [[ $port == 22 ]] || name="[$host]:$port"
  key=$(cut -d' ' -f1-2 "$host_key.pub")
  echo "$name $key" >"$state/known_hosts.pallas"
  ssh -o "UserKnownHostsFile=$state/known_hosts.pallas" -o StrictHostKeyChecking=yes -p "${PALLAS_SSH_PORT:-22}" "sgiath@$host" bash -s <<'EOF'
set -u
echo "== system"; readlink /run/current-system; uname -r
echo "== failed units"; systemctl --failed --no-legend
echo "== secrets"; sudo ls /run/secrets
echo "== nebula"; ip -br addr show nebula.sgiath 2>/dev/null || echo "no nebula interface"
echo "== boot"; sudo bootctl list --no-pager | grep -E 'title|id:'
echo "== disks"; lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS
echo "== gpu"; nvidia-smi -L 2>&1 | head -3
EOF
  ;;

*)
  die "unknown command $cmd"
  ;;
esac
