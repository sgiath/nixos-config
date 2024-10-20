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
  options.services.matrix.enable = lib.mkEnableOption "matrix server";

  config = lib.mkIf (config.sgiath.server.enable && config.services.matrix.enable) {
    services = {
      matrix-conduit = {
        enable = true;
        package = pkgs.conduwuit;
        settings.global = {
          # server
          server_name = "sgiath.dev";
          address = "0.0.0.0";
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
