{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.sgiath.amd-gpu;
in 
{
  options.sgiath.amd-gpu = {
    enable = lib.mkEnableOption "AMD GPU";
  };

  config = lib.mkIf cfg.enable {
    boot = {
      initrd.kernelModules = [ "amdgpu" ];
      kernelModules = [ "kvm-amd" ];
    };

    services.xserver.videoDrivers = [ "amdgpu" ];

    systemd.tmpfiles.rules = [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
        amdvlk
      ];
      extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
    };
  };
}
