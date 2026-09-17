{
  imports = [
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
