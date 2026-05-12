{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.gpu == "nvidia") {
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      open = false;
      # package = config.boot.kernelPackages.nvidiaPackages.beta;

      modesetting.enable = true;

      powerManagement = {
        enable = false;
        finegrained = false;
      };

      nvidiaSettings = true;

      prime = {
        sync.enable = true;
        amdgpuBusId = "PCI:101:0:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}
