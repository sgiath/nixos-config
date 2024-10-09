{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.audiobookshelf.enable) {
    services = {
      nginx.virtualHosts."audio.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:8000";
        };
      };
    };
  };
}
