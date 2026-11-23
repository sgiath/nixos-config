# Counters for the weekly health check, in /var/lib/health-stats:
#
# - samples.jsonl: hourly and at shutdown, btrfs commit times, discard
#   backlog, pressure stall counters and temperatures. The kernel resets
#   these counters at boot and Ceres reboots most days, so samples are
#   appended to a log. Writing 0 to commit_stats resets only max_commit_ms,
#   so each sample's max covers the time since the previous one.
#   Temperatures and GPU power are point readings, except the gpu_*_max,
#   gpu_throttle_mask and gpu_temp_throttle_s fields, which cover the
#   watcher's 10-second readings since the previous sample.
# - commit-spikes.jsonl: every 10-second window in which btrfs spent more
#   than 2 s committing, so a freeze can be matched to the journal.
# - smart.jsonl: daily NVMe health counters, keyed by drive serial.
{ lib, pkgs, ... }:
let
  dir = "/var/lib/health-stats";
  # Written by the watcher, read and reset by the hourly sample.
  gpuState = "/run/health-stats/gpu";
  lock = "/run/health-stats/lock";

  common = ''
    fs="/sys/fs/btrfs/$(findmnt -no UUID /)"
    boot_id="$(cat /proc/sys/kernel/random/boot_id)"
    commit() { awk -v k="$1" '$1 == k { print $2 }' "$fs/commit_stats"; }
    psi() { awk -v k="$2" '$1 == k { sub("total=", "", $5); print $5 }' "/proc/pressure/$1"; }
    # Prints value / divisor, or null when the sensor is missing or not ready.
    reading() {
      local v
      if v="$(cat "$1" 2>/dev/null)" && [[ -n "$v" ]]; then echo $((v / $2)); else echo null; fi
    }
    hwmon_dir() {
      local h
      for h in /sys/class/hwmon/hwmon*; do
        if [[ "$(cat "$h/name")" == "$1" ]]; then
          echo "$h"
          return
        fi
      done
    }
    hwmon() {
      local h
      h="$(hwmon_dir "$1")"
      if [[ -n "$h" ]]; then reading "$h/$2" "$3"; else echo null; fi
    }
  '';

  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.util-linux
  ];

  sample = pkgs.writeShellApplication {
    name = "health-stats-sample";
    inherit runtimeInputs;
    text = common + ''
      # Controller names change between boots, so drives are keyed by serial.
      nvme_temps() {
        local n h serial out=""
        for n in /sys/class/nvme/nvme*; do
          read -r serial < "$n/serial"
          for h in "$n"/hwmon*; do
            out+="''${out:+,}\"$serial\":$(reading "$h/temp1_input" 1000)"
          done
        done
        echo "{$out}"
      }

      max="$(commit max_commit_ms)"
      echo 0 > "$fs/commit_stats"

      # The lock is held until the sample is written, and the watcher's
      # state is cleared only after that, so a failed write loses no peak.
      gpu_junction_max=null gpu_power_max=null gpu_throttle_mask=null gpu_temp_throttle_s=null
      exec 9> ${lock}
      flock 9
      if [[ -r ${gpuState} ]]; then
        read -r gpu_junction_max gpu_power_max gpu_throttle_mask gpu_temp_throttle_s < ${gpuState}
      fi

      printf '{"ts":"%s","boot_id":"%s","commits":%s,"total_commit_ms":%s,"max_commit_ms":%s,"discardable_bytes":%s,"discardable_extents":%s,"cpu_some_us":%s,"io_some_us":%s,"io_full_us":%s,"memory_some_us":%s,"memory_full_us":%s,"cpu_tctl_c":%s,"gpu_junction_c":%s,"gpu_mem_c":%s,"gpu_power_w":%s,"gpu_junction_max_c":%s,"gpu_power_max_w":%s,"gpu_throttle_mask":%s,"gpu_temp_throttle_s":%s,"nvme_c":%s}\n' \
        "$(date -u +%FT%TZ)" "$boot_id" \
        "$(commit commits)" "$(commit total_commit_ms)" "$max" \
        "$(cat "$fs/discard/discardable_bytes")" "$(cat "$fs/discard/discardable_extents")" \
        "$(psi cpu some)" "$(psi io some)" "$(psi io full)" "$(psi memory some)" "$(psi memory full)" \
        "$(hwmon k10temp temp1_input 1000)" \
        "$(hwmon amdgpu temp2_input 1000)" "$(hwmon amdgpu temp3_input 1000)" \
        "$(hwmon amdgpu power1_average 1000000)" \
        "$gpu_junction_max" "$gpu_power_max" "$gpu_throttle_mask" "$gpu_temp_throttle_s" \
        "$(nvme_temps)" \
        >> ${dir}/samples.jsonl
      rm -f ${gpuState}
    '';
  };

  watch = pkgs.writeShellApplication {
    name = "health-stats-watch";
    inherit runtimeInputs;
    text = common + ''
      interval=10
      prev_total="" prev_commits="" prev_io=""

      # Hotspot (C), socket power (W) and the ASIC-independent throttler bits
      # from gpu_metrics v1.3 (Navi 21; offsets from struct gpu_metrics_v1_3
      # in the kernel's kgd_pp_interface.h). Fails on any other layout, with
      # the reason in gpu_error.
      read_gpu() {
        local -a b=()
        local i h
        h="$(hwmon_dir amdgpu)"
        if [[ -z "$h" ]]; then
          gpu_error="no amdgpu hwmon device"
          return 1
        fi
        read -ra b < <(od -An -v -t u1 -w256 "$h/device/gpu_metrics" 2>/dev/null) || true
        if ((''${#b[@]} != 120 || b[0] + b[1] * 256 != 120 || b[2] != 1 || b[3] != 3)); then
          gpu_error="$h/device/gpu_metrics is not a readable v1.3 table (''${#b[@]} bytes, version ''${b[2]:-?}.''${b[3]:-?})"
          return 1
        fi
        hotspot=$((b[6] + b[7] * 256))
        power=$((b[22] + b[23] * 256))
        throttle=0
        for i in 7 6 5 4 3 2 1 0; do
          throttle=$((throttle * 256 + b[112 + i]))
        done
      }

      gpu_error="" gpu_failing=0

      while true; do
        commits="$(commit commits)"
        total="$(commit total_commit_ms)"
        io="$(psi io full)"
        if [[ -n "$prev_total" ]] && ((total - prev_total > 2000)); then
          printf '{"ts":"%s","boot_id":"%s","commits":%s,"commit_ms":%s,"last_commit_ms":%s,"io_full_ms":%s}\n' \
            "$(date -u +%FT%TZ)" "$boot_id" "$((commits - prev_commits))" "$((total - prev_total))" \
            "$(commit last_commit_ms)" "$(((io - prev_io) / 1000))" \
            >> ${dir}/commit-spikes.jsonl
        fi
        prev_total="$total" prev_commits="$commits" prev_io="$io"

        # Logged once when reads start failing and once when they recover.
        if read_gpu; then
          if ((gpu_failing)); then
            echo "gpu_metrics readable again; GPU peaks are recorded" >&2
            gpu_failing=0
          fi
          # Throttler bits 32-47 are the temperature and VR-hot limits.
          temp_s=0
          if ((throttle >> 32 & 0xffff)); then temp_s="$interval"; fi
          jmax=0 pmax=0 mask=0 temp_total=0
          exec 9> ${lock}
          flock 9
          if [[ -r ${gpuState} ]]; then read -r jmax pmax mask temp_total < ${gpuState}; fi
          echo "$((hotspot > jmax ? hotspot : jmax)) $((power > pmax ? power : pmax)) $((mask | throttle)) $((temp_total + temp_s))" > ${gpuState}
          exec 9>&-
        elif ((!gpu_failing)); then
          echo "$gpu_error; GPU peaks are not recorded until it reads again" >&2
          gpu_failing=1
        fi

        sleep "$interval"
      done
    '';
  };

  smart = pkgs.writeShellApplication {
    name = "health-stats-smart";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.nvme-cli
    ];
    text = ''
      drives="{}"
      for n in /sys/class/nvme/nvme*; do
        read -r serial < "$n/serial"
        log="$(nvme smart-log -o json "/dev/$(basename "$n")")"
        drives="$(jq -c --arg s "$serial" --argjson log "$log" \
          '.[$s] = ($log | {critical_warning, avail_spare, percent_used, media_errors, num_err_log_entries, unsafe_shutdowns, power_cycles, power_on_hours, data_units_written, warning_temp_time, critical_comp_time})' \
          <<< "$drives")"
      done
      jq -cn --arg ts "$(date -u +%FT%TZ)" --arg boot_id "$(cat /proc/sys/kernel/random/boot_id)" \
        --argjson drives "$drives" '{ts: $ts, boot_id: $boot_id, drives: $drives}' \
        >> ${dir}/smart.jsonl
    '';
  };

  serviceConfig = {
    StateDirectory = "health-stats";
    RuntimeDirectory = "health-stats";
    RuntimeDirectoryPreserve = true;
  };
  oneshot = serviceConfig // {
    Type = "oneshot";
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
        serviceConfig = oneshot // {
          ExecStart = lib.getExe sample;
        };
      };

      health-stats-shutdown = {
        description = "Sample btrfs, pressure and temperature counters at shutdown";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = oneshot // {
          RemainAfterExit = true;
          ExecStop = lib.getExe sample;
        };
      };

      health-stats-watch = {
        description = "Record btrfs commit spikes and GPU peaks every 10 seconds";
        wantedBy = [ "multi-user.target" ];
        # Stops before health-stats-shutdown takes the last sample.
        after = [ "health-stats-shutdown.service" ];
        serviceConfig = serviceConfig // {
          ExecStart = lib.getExe watch;
          Restart = "always";
          RestartSec = 10;
        };
      };

      health-stats-smart = {
        description = "Record NVMe health counters";
        serviceConfig = oneshot // {
          ExecStart = lib.getExe smart;
        };
      };
    };

    timers = {
      health-stats = {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = "hourly";
      };

      health-stats-smart = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    };
  };
}
