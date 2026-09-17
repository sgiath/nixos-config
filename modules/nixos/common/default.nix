{ config, lib, ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./nas.nix
    ./networking.nix
    ./nebula.nix
    ./nix.nix
    ./optimizations.nix
    ./secrets.nix
    ./security.nix
    ./udev.nix
    ./usb.nix
    ./users.nix
    ./yggdrasil.nix
  ];

  options.sgiath.enable = lib.mkEnableOption "sgiath config";
  options.sgiath.nas.enable = lib.mkEnableOption "Synology SMB mounts";

  config = lib.mkIf config.sgiath.enable {
    system = {
      stateVersion = "23.11";
    };

    home-manager.users.sgiath.sgiath = {
      enable = true;
      roles.terminal.enable = true;
    };
  };
}
