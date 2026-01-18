{ config, lib, ... }:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  options.services.opencode-proxy.enable = lib.mkEnableOption "OpenCode proxy";

  config = lib.mkIf (config.sgiath.server.enable && config.services.opencode-proxy.enable) {
    services.nginx.virtualHosts = {
      "opencode.sgiath.dev" = {
        basicAuth = {
          sgiath = secrets.opencodePassword;
        };

        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        locations = {
          "/" = {
            proxyWebsockets = true;
            proxyPass = "http://192.168.1.7:12345";
          };
        };
      };
    };
  };
}
