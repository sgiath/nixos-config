{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    boot = {
      kernel.sysctl = {
        "fs.file-max" = 524288;
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 524288;
        "fs.inotify.max_queued_events" = 65536;

        # zram reclaim: anonymous pages compress in RAM, so prefer them
        # over dropping page cache. See omarchy etc/sysctl.d/99-omarchy-sysctl.conf.
        "vm.swappiness" = 150;
        "vm.vfs_cache_pressure" = 50;
        "vm.page-cluster" = 0;
        "vm.watermark_boost_factor" = 0;
        "vm.watermark_scale_factor" = 125;
        "vm.dirty_background_bytes" = 67108864;
        "vm.dirty_bytes" = 268435456;
        "vm.dirty_writeback_centisecs" = 500;
        "vm.dirty_expire_centisecs" = 1500;
      };
      kernelParams = [ "threadirqs" ];
      extraModprobeConfig = ''
        options usbcore autosuspend=-1
      '';
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 100;
    };

    # Power settings
    powerManagement.cpuFreqGovernor = "performance";
    services = {
      power-profiles-daemon.enable = false;
      tuned.enable = true;
      upower.enable = true;
    };

    # Kill a runaway app, not the session. enableUserSlices would mark
    # user@.service and make Hyprland eligible.
    systemd = {
      oomd = {
        enable = true;
        enableRootSlice = false;
        enableSystemSlice = false;
        enableUserSlices = false;
        settings.OOM = {
          DefaultMemoryPressureLimit = "50%";
          DefaultMemoryPressureDurationSec = "20s";
        };
      };
      user.slices = {
        app.sliceConfig = {
          ManagedOOMMemoryPressure = "kill";
          ManagedOOMSwap = "kill";
        };
      };
      settings.Manager = {
        DefaultTimeoutStopSec = "5s";
        DefaultLimitNOFILE = "65536:524288";
      };
      user.settings.Manager = {
        DefaultTimeoutStopSec = "5s";
        DefaultLimitNOFILE = "65536:524288";
      };
      services."user@".serviceConfig.TimeoutStopSec = "5s";
    };
  };
}
