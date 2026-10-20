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

  # Nebula lighthouse/relay for every other host; needs UDP 4242 forwarded
  # from the router so roaming peers reach it via nebula.sgiath.dev.
  services.nebula.networks.sgiath = {
    isLighthouse = true;
    isRelay = true;

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

  # Home-Wi-Fi access for mobile nodes; the gateway remains loopback-only.
  services.nginx.virtualHosts.openclaw-lan = {
    listen = [
      {
        addr = "192.168.1.2";
        port = 18790;
      }
    ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:18789";
      proxyWebsockets = true;
      recommendedProxySettings = false;
      extraConfig = ''
        allow 192.168.1.0/24;
        deny all;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
      '';
    };
  };

  virtualisation.docker.enable = true;
}
