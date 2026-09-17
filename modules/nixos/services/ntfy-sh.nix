{ config, lib, ... }:
let
  nebula = config.sgiath.nebula;
  host = "ntfy.sgiath.dev";
in
{
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "ntfy" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.services.ntfy-sh.enable) {
      services = {
        ntfy-sh = {
          settings = {
            base-url = "https://${host}";
            listen-http = ":5689";
            behind-proxy = true;
          };
        };

        nginx.virtualHosts.${host} = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          # Overlay only
          extraConfig = ''
            allow ${nebula.cidr4};
            allow ${nebula.cidr6};
            deny all;
          '';

          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:5689";
          };
        };
      };
    })
  ];
}
