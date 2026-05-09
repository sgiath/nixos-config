{
  config,
  lib,
  ...
}:
{
  options.services.eve-proxy.enable = lib.mkEnableOption "EVE proxy";
  config = lib.mkIf (config.sgiath.server.enable && config.services.eve-proxy.enable) {
    services.nginx.virtualHosts."eve.sgiath.dev" = {
      # SSL
      onlySSL = true;
      kTLS = true;

      # ACME
      enableACME = true;
      acmeRoot = null;

      locations."/" = {
        proxyPass = "http://192.168.1.6:4000";
      };
    };
  };
}
