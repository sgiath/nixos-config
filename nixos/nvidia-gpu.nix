
{
  config,
  lib,
  ...
}:

{
  options.sgiath.nvidia-gpu = {
    enable = lib.mkEnableOption "Nvidia GPU";
  };

  config = lib.mkIf config.sgiath.nvidia-gpu.enable {
    boot.initrd.kernelModules = [ "nvidia" ];
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware = {
      graphics.enable = true;

      nvidia = {
        open = false;
        package = config.boot.kernelPackages.nvidiaPackages.beta;

        modesetting.enable = true;

        powerManagement = {
          enable = false;
          finegrained = false;
        };

        nvidiaSettings = true;
      };
    };
  };
}
