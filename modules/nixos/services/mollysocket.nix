{ config, lib, ... }:
let
  nebula = config.sgiath.nebula;
  host = "mollysocket.sgiath.dev";
in
{
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "mollysocket" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && config.services.mollysocket.enable) {
      services = {
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
            proxyPass = "http://127.0.0.1:8020";
          };
        };
      };
    })
  ];
}
