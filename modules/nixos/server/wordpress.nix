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
        acmeRoot = "/data/www/romana-vaverova.cz";

        # QUIC
        http3_hq = true;
        quic = true;

        locations = {
          "/.well-known" = {
            root = "/data/www/romana-vaverova.cz";
          };

          "/" = {
            proxyPass = "http://127.0.0.1:8081";
          };
        };
      };
    };
  };
}
