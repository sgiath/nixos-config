{ config, lib, ... }:
{
  config = lib.mkIf config.sgiath.enable {
    boot = {
      extraModulePackages = with config.boot.kernelPackages; [ zenpower ];
      kernel.sysctl = {
        "vm.swappiness" = 10;
        "fs.file-max" = 524288;
        "fs.inotify.max_user_watches" = 524288;
        "fs.inotify.max_user_instances" = 524288;
        "fs.inotify.max_queued_events" = 65536;
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
