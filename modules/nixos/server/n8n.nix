{ namespace, config, lib, pkgs, ... }:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.n8n.enable) {
    services = {
      nginx.virtualHosts."n8n.sgiath.dev" = {
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
          proxyPass = "http://127.0.0.1:5678";
        };
      };

      n8n = {
        package = pkgs.${namespace}.n8n;
        webhookUrl = "https://n8n.sgiath.dev/";
        settings = {
          # ai.enabled = true;
        };
      };
    };

    environment.systemPackages = [
      pkgs.nodejs_22
    ];
  };
}
