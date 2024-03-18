{ pkgs, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix
    ./monitors.nix

    # modules
    ../../system/x11.nix
    ../../system/sound.nix
    ../../system/printing.nix
    ../../system/gaming.nix
    ../../system/bluetooth.nix

    # work
    ../../work/nginx.nix
  ];

  networking.hostName = "ceres";

  # AMD GPU
  services.xserver.videoDrivers = [ "amdgpu" ];
  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];
  hardware.opengl = {
    extraPackages = with pkgs; [ rocmPackages.clr.icd amdvlk ];
    extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
  };

  # temporary, move it out
  virtualisation.docker.enable = true;
}
