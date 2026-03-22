{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    boot = {
      extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
      kernel.sysctl = {
        "vm.swappiness" = 10;
        "vm.max_map_count" = 2147483642;
        "fs.file-max" = 524288;
        "net.ipv4.tcp_fin_timeout" = 5;
        "kernel.sched_cfs_bandwidth_slice_us" = 3000;
      };
      kernelParams = [ "threadirqs" ];
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 25;
    };

    # Power settings
    powerManagement.cpuFreqGovernor = "performance";
    services = {
      power-profiles-daemon.enable = false;
      tuned.enable = true;
      upower.enable = true;
    };
  };
}
