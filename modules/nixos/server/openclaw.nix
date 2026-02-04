{ config, lib, ... }:
{
  options.services.openclaw-proxy.enable = lib.mkEnableOption "OpenClaw proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.openclaw-proxy.enable) {
    services.nginx.virtualHosts = {
      "niamh.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations = {
          "/hooks" = {
            proxyPass = "http://192.168.1.7:18789";
          };
        };
      };
    };
  };
}
