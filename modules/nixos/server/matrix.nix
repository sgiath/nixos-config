{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  options.services.matrix = {
    enable = lib.mkEnableOption "matrix server";
  };

  config = lib.mkIf (config.sgiath.server.enable && config.services.matrix.enable) {
    services = {
      matrix-conduit = {
        enable = true;
        package = pkgs.conduwuit.all-features;
        settings.global = {
          # server
          server_name = "sgiath.dev";
          address = "127.0.0.1";
          port = 6167;

          database_backend = "rocksdb";

          # registration
          allow_registration = true;
          registration_token = secrets.matrix_registration_token;

          # other
          admin_console_automatic = true;
          new_user_displayname_suffix = "";
        };
      };

      nginx.virtualHosts = {
        "sgiath.dev".locations = {
          "/.well-known/matrix/server" = {
            extraConfig = ''
              add_header Access-Control-Allow-Origin '*';
              add_header Cross-Origin-Resource-Policy 'cross-origin';

              default_type application/json;

              return 200 '{"m.server":"matrix.sgiath.dev"}';
            '';
          };

          "/.well-known/matrix/client" = {
            extraConfig = ''
              add_header Access-Control-Allow-Origin '*';
              add_header Cross-Origin-Resource-Policy 'cross-origin';

              default_type application/json;

              return 200 '{"m.homeserver":{"base_url":"matrix.sgiath.dev"}}';
            '';
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
