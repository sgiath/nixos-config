{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.sgiath.server.enable && config.services.searx.enable) {
    services.searx.package = pkgs.searxng;

    services.nginx.virtualHosts."search.sgiath.dev" = {
      # SSL
      onlySSL = true;
      enableACME = true;
      kTLS = true;

      # QUIC
      http3_hq = true;
      quic = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
      };
    };
  };
}
