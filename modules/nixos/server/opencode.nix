{ config, lib, ... }:
{
  options.services.ai-proxy.enable = lib.mkEnableOption "OpenCode/AoE proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.ai-proxy.enable) {
    services.nginx.virtualHosts = {
      "ai.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations = {
          "/" = {
            proxyWebsockets = true;
            proxyPass = "http://192.168.1.7:62361";
            extraConfig = ''
              proxy_read_timeout 86400;
              proxy_send_timeout 86400;
            '';
          };
        };
      };
    };
  };
}
