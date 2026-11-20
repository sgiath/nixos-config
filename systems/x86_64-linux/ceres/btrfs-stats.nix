# Hourly samples of btrfs commit times, discard backlog and pressure stall
# counters, for the weekly health check. The kernel resets these counters at
# boot and Ceres reboots most days, so samples are appended to a log; the last
# one is taken at shutdown. Writing 0 to commit_stats resets only
# max_commit_ms, so each sample's max covers the time since the previous one.
{ lib, pkgs, ... }:
let
  sample = pkgs.writeShellApplication {
    name = "btrfs-stats-sample";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.util-linux
    ];
    text = ''
      fs="/sys/fs/btrfs/$(findmnt -no UUID /)"
      commit() { awk -v k="$1" '$1 == k { print $2 }' "$fs/commit_stats"; }
      psi() { awk -v k="$2" '$1 == k { sub("total=", "", $5); print $5 }' "/proc/pressure/$1"; }

      max="$(commit max_commit_ms)"
      echo 0 > "$fs/commit_stats"

      printf '{"ts":"%s","boot_id":"%s","commits":%s,"total_commit_ms":%s,"max_commit_ms":%s,"discardable_bytes":%s,"discardable_extents":%s,"io_some_us":%s,"io_full_us":%s,"memory_some_us":%s,"memory_full_us":%s}\n' \
        "$(date -u +%FT%TZ)" "$(cat /proc/sys/kernel/random/boot_id)" \
        "$(commit commits)" "$(commit total_commit_ms)" "$max" \
        "$(cat "$fs/discard/discardable_bytes")" "$(cat "$fs/discard/discardable_extents")" \
        "$(psi io some)" "$(psi io full)" "$(psi memory some)" "$(psi memory full)" \
        >> /var/lib/btrfs-stats/samples.jsonl
    '';
  };

  serviceConfig = {
    Type = "oneshot";
    StateDirectory = "btrfs-stats";
  };
in
{
  environment.systemPackages = [ pkgs.nvme-cli ];

  systemd = {
    services = {
      btrfs-stats = {
        description = "Sample btrfs commit and IO pressure counters";
        serviceConfig = serviceConfig // {
          ExecStart = lib.getExe sample;
        };
      };

      btrfs-stats-shutdown = {
        description = "Sample btrfs commit and IO pressure counters at shutdown";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = serviceConfig // {
          RemainAfterExit = true;
          ExecStop = lib.getExe sample;
        };
      };
    };

    timers.btrfs-stats = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "hourly";
    };
  };
}
