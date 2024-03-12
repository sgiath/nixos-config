{ config, pkgs, userSettings, ... }:

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

  # temporary, move it out
  virtualisation.docker.enable = true;
}
