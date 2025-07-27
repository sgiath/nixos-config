{
  config,
  lib,
  ...
}:
{
  options.services.wordpress.proxy = lib.mkEnableOption "Wordpress proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.wordpress.proxy) {
    services = {
      nginx.virtualHosts."romana-vaverova.cz" = {
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
          proxyPass = "http://127.0.0.1:8081";
        };
      };
    };
  };
}
