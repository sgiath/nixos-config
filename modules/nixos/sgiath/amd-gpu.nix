{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.enable && (config.sgiath.gpu == "amd")) {
    boot.kernelModules = [ "kvm-amd" ];
    services.xserver.videoDrivers = [ "amdgpu" ];

    environment.systemPackages = with pkgs.rocmPackages; [
      pkgs.clinfo
      rocminfo
      rocm-smi
      clr
    ];

    hardware = {
      amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
      };
      graphics = {
        # extraPackages = with pkgs; [ amdvlk ];
        extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
      };
    };
  };
}
