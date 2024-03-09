{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../system.nix

    # hardware
    ./hardware.nix
  ];

  networking.hostName = "vesta";

  boot.kernelPackages = pkgs.linuxPackages_zen;
}
