{
  lib,
  pkgs,
  inputs,
  namespace,
  modulesPath,
  ...
}:
let
  cachePolicy = (import ../../../flake.nix).nixConfig;
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  nixpkgs.hostPlatform = "x86_64-linux";

  isoImage = {
    makeEfiBootable = true;
    makeUsbBootable = true;
    appendToMenuLabel = " live";
  };

  # Snapshot of this repository; `live-install` copies it to ~/nixos.
  environment.etc."sgiath/nixos".source = ../../../.;

  users.mutableUsers = false;
  users.users.sgiath = import ../../../modules/nixos/common/account.nix // {
    extraGroups = [ "wheel" ];
  };
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
  services.getty.autologinUser = lib.mkForce "sgiath";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    trusted-users = [ "sgiath" ];
    substituters = cachePolicy.extra-substituters;
    trusted-public-keys = cachePolicy.extra-trusted-public-keys;
  };

  environment.systemPackages = with pkgs; [
    pkgs.${namespace}.live-install
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
    neovim
    parted
    git
    gnupg
    pinentry-curses
    sops
    ssh-to-age
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce [
      "ext4"
      "btrfs"
      "reiserfs"
      "vfat"
      "f2fs"
      "xfs"
      "ntfs"
      "cifs"
    ];
  };

  services.tor = {
    enable = true;
    client = {
      enable = true;
      dns.enable = true;
      transparentProxy.enable = true;
    };
  };
}
