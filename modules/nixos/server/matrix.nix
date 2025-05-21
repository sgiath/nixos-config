{
  config,
  lib,
  ...
}:
let
  secrets = builtins.fromJSON (builtins.readFile ./../../../secrets.json);
in
{
  options.services.matrix.enable = lib.mkEnableOption "matrix server";

  config = lib.mkIf (config.sgiath.server.enable && config.services.matrix.enable) {
    services = {
      matrix-conduit = {
        enable = true;
        settings.global = {
          # server
          server_name = "sgiath.dev";
          address = "0.0.0.0";
          port = 6167;

          database_backend = "rocksdb";

          # registration
          allow_registration = true;
          registration_token = secrets.matrix_registration_token;

          trusted_servers = [
            "matrix.org"
            "nixos.org"
          ];
        };
      };

      nginx.virtualHosts = {
        "sgiath.dev".locations = {
          # server <-> server
          "/.well-known/matrix/server" = {
            extraConfig = ''
              add_header Access-Control-Allow-Origin '*';
              add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
              add_header Access-Control-Allow-Headers 'X-Requested-With, Content-Type, Authorization';
              add_header Cross-Origin-Resource-Policy 'cross-origin';

              default_type application/json;
            '';
            return = "200 '{\"m.server\":\"matrix.sgiath.dev:443\"}'";
          };

          # client <-> server
          "/.well-known/matrix/client" = {
            extraConfig = ''
              add_header Access-Control-Allow-Origin '*';
              add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
              add_header Access-Control-Allow-Headers 'X-Requested-With, Content-Type, Authorization';
              add_header Cross-Origin-Resource-Policy 'cross-origin';

              default_type application/json;
            '';
            return = "200 '{\"m.homeserver\":{\"base_url\":\"https://matrix.sgiath.dev\"}}'";
          };

          # server support
          "/.well-known/matrix/support" = {
            extraConfig = ''
              add_header Access-Control-Allow-Origin '*';
              add_header Access-Control-Allow-Methods 'GET, POST, PUT, DELETE, OPTIONS';
              add_header Access-Control-Allow-Headers 'X-Requested-With, Content-Type, Authorization';
              add_header Cross-Origin-Resource-Policy 'cross-origin';

              default_type application/json;
            '';
            return = "200 '{\"contacts\":[{\"email_address\":\"matrix@sgiath.dev\",\"matrix_id\":\"@sgiath:sgiath.dev\",\"role\":\"m.role.admin\"}]}'";
          };
        };

        "matrix.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

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
