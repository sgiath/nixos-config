{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.jellyfin.enable) {
    services = {
      jellyfin = {
        openFirewall = true;
      };

      nginx.virtualHosts."watch.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
        };
      };
    };
  };
}
