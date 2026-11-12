{ config, ... }:
let
  nebula = config.services.nebula.networks.sgiath;
in
{
  imports = [
    ./crazyegg.nix
    ./hardware.nix
    ./disko.nix
    ./services.nix
  ];

  networking.hostName = "vesta";
  networking.wireguard.enable = false;

  # Vesta is a Nebula lighthouse/relay through its endpoint in the peers table
  # (modules/nixos/common/nebula.nix); the router forwards UDP 4242 to it.
  services.nebula.networks.sgiath = {
    # Debug SSH for nebula-manager's read-only network view. Bound to the
    # overlay address only (Nebula starts sshd after the interface is up), so
    # just overlay peers reach it, and only with the key below. The app sends
    # read-only commands; the key itself could also close tunnels or reload.
    settings.sshd = {
      enabled = true;
      listen = "${config.sgiath.nebula.peers.vesta.ip4}:2222";
      host_key = config.sops.secrets.nebula-sshd-host-key.path;
      authorized_users = [
        {
          user = "nebula-manager";
          keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA+V4pMO2vMn/L4S8B2n3tlQPUqQIXzWmVtMTEOPvDmm nebula-manager@ceres"
          ];
        }
      ];
    };
  };

  # Public half: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBRFfD529DRzTfnEYxXMP76qDRwacacMxyRZCN/C4Ax
  sops.secrets.nebula-sshd-host-key = {
    sopsFile = ../../../secrets/vesta.yaml;
    key = "nebula_sshd_host_key";
    owner = nebula.user;
    group = nebula.group;
    mode = "0400";
    restartUnits = [ "nebula@sgiath.service" ];
  };

  sgiath = {
    enable = true;
    roles.server.enable = true;
  };

  virtualisation.docker.enable = true;
}
