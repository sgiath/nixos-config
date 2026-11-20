# Hourly samples of btrfs commit times, discard backlog, pressure stall
# counters and temperatures, for the weekly health check. The kernel resets
# these counters at boot and Ceres reboots most days, so samples are appended
# to a log; the last one is taken at shutdown. Writing 0 to commit_stats
# resets only max_commit_ms, so each sample's max covers the time since the
# previous one. Temperatures and GPU power are point readings.
{ lib, pkgs, ... }:
let
  sample = pkgs.writeShellApplication {
    name = "health-stats-sample";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.util-linux
    ];
    text = ''
      fs="/sys/fs/btrfs/$(findmnt -no UUID /)"
      commit() { awk -v k="$1" '$1 == k { print $2 }' "$fs/commit_stats"; }
      psi() { awk -v k="$2" '$1 == k { sub("total=", "", $5); print $5 }' "/proc/pressure/$1"; }
      # Prints value / divisor, or null when the sensor is missing or not ready.
      reading() {
        local v
        if v="$(cat "$1" 2>/dev/null)" && [[ -n "$v" ]]; then echo $((v / $2)); else echo null; fi
      }
      hwmon() {
        local h
        for h in /sys/class/hwmon/hwmon*; do
          if [[ "$(cat "$h/name")" == "$1" ]]; then
            reading "$h/$2" "$3"
            return
          fi
        done
        echo null
      }
      nvme() {
        local h
        for h in /sys/class/nvme/"$1"/hwmon*; do
          reading "$h/temp1_input" 1000
          return
        done
      }

      max="$(commit max_commit_ms)"
      echo 0 > "$fs/commit_stats"

      printf '{"ts":"%s","boot_id":"%s","commits":%s,"total_commit_ms":%s,"max_commit_ms":%s,"discardable_bytes":%s,"discardable_extents":%s,"cpu_some_us":%s,"io_some_us":%s,"io_full_us":%s,"memory_some_us":%s,"memory_full_us":%s,"cpu_tctl_c":%s,"gpu_junction_c":%s,"gpu_mem_c":%s,"gpu_power_w":%s,"nvme0_c":%s,"nvme1_c":%s,"nvme2_c":%s}\n' \
        "$(date -u +%FT%TZ)" "$(cat /proc/sys/kernel/random/boot_id)" \
        "$(commit commits)" "$(commit total_commit_ms)" "$max" \
        "$(cat "$fs/discard/discardable_bytes")" "$(cat "$fs/discard/discardable_extents")" \
        "$(psi cpu some)" "$(psi io some)" "$(psi io full)" "$(psi memory some)" "$(psi memory full)" \
        "$(hwmon k10temp temp1_input 1000)" \
        "$(hwmon amdgpu temp2_input 1000)" "$(hwmon amdgpu temp3_input 1000)" \
        "$(hwmon amdgpu power1_average 1000000)" \
        "$(nvme nvme0)" "$(nvme nvme1)" "$(nvme nvme2)" \
        >> /var/lib/health-stats/samples.jsonl
    '';
  };

  serviceConfig = {
    Type = "oneshot";
    StateDirectory = "health-stats";
  };
in
{
  # Read by the weekly health check.
  environment.systemPackages = [
    pkgs.dmidecode
    pkgs.ethtool
    pkgs.lm_sensors
    pkgs.nvme-cli
    pkgs.pciutils
    pkgs.smartmontools
    pkgs.usbutils
  ];

  systemd = {
    services = {
      health-stats = {
        description = "Sample btrfs, pressure and temperature counters";
        serviceConfig = serviceConfig // {
          ExecStart = lib.getExe sample;
        };
      };

      health-stats-shutdown = {
        description = "Sample btrfs, pressure and temperature counters at shutdown";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = serviceConfig // {
          RemainAfterExit = true;
          ExecStop = lib.getExe sample;
        };
      };
    };

    timers.health-stats = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "hourly";
    };
  };
}
