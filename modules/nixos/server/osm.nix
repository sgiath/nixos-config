{ config, lib, ... }:
{
  options.services.osm = {
    enable = lib.mkEnableOption "OSM server";
    proxy = lib.mkEnableOption "OSM proxy";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.osm.proxy) {
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
          proxyPass = "http://127.0.0.1:8088";
        };
      };
    };
  };
}
