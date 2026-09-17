{
  config,
  lib,
  pkgs,
  ...
}:
let
  nebula = config.sgiath.nebula;
  host = "torrent.sgiath.dev";
in
{
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "torrent" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.services.transmission.enable) {
      services = {
        transmission = {
          openPeerPorts = true;
          performanceNetParameters = true;
          package = pkgs.transmission_4;
          webHome = pkgs.flood-for-transmission;

          settings = {
            download-dir = "/nas/downloads";
            # Nebula certificate is the auth; nginx only admits overlay clients
            # and Transmission only listens for nginx on loopback.
            rpc-authentication-required = false;
            # Without password auth Transmission enforces its Host whitelist.
            rpc-host-whitelist = host;
          };
        };

        nginx.virtualHosts.${host} = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          # Overlay only
          extraConfig = ''
            allow ${nebula.cidr4};
            allow ${nebula.cidr6};
            deny all;
          '';

          locations."/" = {
            proxyPass = "http://127.0.0.1:9091";
            proxyWebsockets = true;
          };
        };
      };
      systemd.services.nginx.after = [ "transmission.service" ];
    })
  ];
}
