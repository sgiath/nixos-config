{ config, lib, ... }:
{
  imports = [
    ./boot.nix
    ./codex.nix
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
  options.sgiath.publicIPv4 = lib.mkOption {
    type = lib.types.str;
    default = "193.165.30.198";
    readOnly = true;
    description = ''
      Public IPv4 of the router in front of Vesta. The Nebula lighthouse
      endpoint and the TURN/LiveKit advertised addresses are derived from it;
      the public DNS records (nebula, turn, vhosts) must match it by hand.
    '';
  };

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
