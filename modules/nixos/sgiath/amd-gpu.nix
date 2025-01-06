{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.enable && (config.sgiath.gpu == "amd")) {
    boot = {
      initrd.kernelModules = [ "amdgpu" ];
      kernelModules = [ "kvm-amd" ];
    };

    services.xserver.videoDrivers = [ "amdgpu-pro" ];

    systemd.tmpfiles.rules = [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];

    hardware.graphics = {
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
        amdvlk
      ];
      extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
    };
  };
}
