{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable) {
    services = {
      nginx.virtualHosts."osm.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        # static files
        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:8553";
        };
      };
    };
  };
}
