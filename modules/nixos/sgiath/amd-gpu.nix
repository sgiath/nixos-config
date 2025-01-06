{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.enable && (config.sgiath.gpu == "amd")) {
    boot.kernelModules = [ "kvm-amd" ];
    services.xserver.videoDrivers = [ "amdgpu" ];

    hardware = {
      amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
        amdvlk = {
          enable = true;
          supportExperimental.enable = true;
          support32Bit.enable = true;
        };
      };
    };
  };
}
