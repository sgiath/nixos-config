{ config, lib, ... }:
{
  options.services.monitoring = {
    enable = lib.mkEnableOption "monitoring";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.monitoring.enable) {
    services = {
      prometheus = {
        enable = true;
        port = 9090;
        webExternalUrl = "https://monitoring.sgiath.dev";
      };

      grafana = {
        enable = true;
        settings = {
          server = {
            root_url = "https://monitoring.sgiath.dev";
          };
        };
      };

      nginx.virtualHosts."monitoring.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:3000";
        };
      };
    };
  };
}
