{ config, lib, pkgs, ... }:

{
  options.sgiath.amd-gpu = { enable = lib.mkEnableOption "AMD GPU"; };

  config = lib.mkIf config.sgiath.amd-gpu.enable {
    boot = {
      initrd.kernelModules = [ "amdgpu" ];
      kernelModules = [ "kvm-amd" ];
    };

    services.xserver.videoDrivers = [ "amdgpu" ];

    systemd.tmpfiles.rules =
      [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];

    hardware.opengl = {
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
        amdvlk
      ];
      extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
    };
  };
}
