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
      # kernelParams = [ "threadirqs" ];
    };

    # Power settings
    powerManagement.cpuFreqGovernor = "performance";
    services.power-profiles-daemon.enable = false;
    services.tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 80;
      };
    };
  };
}
