{ pkgs, ... }:

{
  imports = [
    # hardware
    ./hardware.nix

    ../../nixos
    ../../nixos/bitcoin.nix
  ];

  networking.hostName = "vesta";

  boot.kernelPackages = pkgs.linuxPackages_zen;
}
