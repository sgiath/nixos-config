{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.matrix-conduit.enable) {
    services = {
      matrix-conduit = {
        package = pkgs.conduwuit.all-features;
        settings.global = {
          address = "127.0.0.1";
          server_name = "sgiath.dev";
        };
      };

      nginx.virtualHosts = {
        "sgiath.dev".locations = {
          "/.well-known/matrix/server" = {
            extraConfig = ''
              default_type application/json;
            '';
            return = "200 '{\"m.server\":\"matrix.sgiath.dev\"}'";
          };

          "/.well-known/matrix/client" = {
            extraConfig = ''
              default_type application/json;
            '';
            return = "200 '{\"m.homeserver\":{\"base_url\":\"matrix.sgiath.dev\"}}'";
          };
        };

        "matrix.sgiath.dev" = {
          # SSL
          onlySSL = true;
          enableACME = true;
          kTLS = true;

          # QUIC
          http3_hq = true;
          quic = true;

          # static files
          locations."/" = {
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:6167";
          };
        };
      };
    };
  };
}
