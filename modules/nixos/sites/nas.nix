{ config, lib, ... }:
let
  nebula = config.sgiath.nebula;
in
{
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "nas" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.sgiath.sites.nas.enable) {
      services.nginx.virtualHosts = {
        "nas.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          # Overlay only: DSM is an admin login and must not face the internet.
          extraConfig = ''
            allow ${nebula.cidr4};
            allow ${nebula.cidr6};
            deny all;
          '';

          locations = {
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://192.168.1.4:5000";
            };
          };
        };
      };
    })
  ];
}
