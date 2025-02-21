{ lib, pkgs, modulesPath, ... }:

{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  nixpkgs = {
    hostPlatform = pkgs.system;
    config.allowUnfree = true;
  };

  environment.systemPackages = with pkgs; [
    neovim
    parted
    git
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
  };

  services.tor = {
    enable = true;
    client = {
      enable = true;
      dns.enable = true;
      transparentProxy.enable = true;
    };
  };

  users.mutableUsers = false;

  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
    appendToMenuLabel = " live";
  };
}
