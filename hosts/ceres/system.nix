{ pkgs, ... }:

{
  imports = [
    # hardware
    ./hardware.nix
    ./monitors.nix

    # modules
    ../../nixos

    # work
    ../../work/nginx.nix
  ];

  networking.hostName = "ceres";

  sgiath = {
    audio.enable = true;
    amd-gpu.enable = true;
    bluetooth.enable = true;
    printing.enable = true;
    gaming.enable = true;
    networking.localDNS.enable = true;
    x11.enable = true;
    # wayland.enable = true;
  };

  # temporary, move it out
  virtualisation.docker.enable = true;
}
