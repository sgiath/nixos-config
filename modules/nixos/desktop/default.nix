{ config, lib, ... }:
{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./printing.nix
    ./stylix.nix
    ./wayland.nix
  ];

  options.sgiath.roles.desktop.enable = lib.mkEnableOption "graphical workstation role";

  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home-manager.users.sgiath.sgiath.roles.desktop.enable = true;
    # Proton Mail Bridge self-signed CA for 127.0.0.1. aerc uses the
    # system bundle; `trust anchor` does not persist on NixOS.
    security.pki.certificateFiles = [ ./protonmail-bridge.crt ];
  };
}
