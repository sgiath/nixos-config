{
  inputs,
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
      matrix-continuwuity = {
        enable = true;
        # package = inputs.conduit.packages.${pkgs.stdenv.hostPlatform.system}.default;
        # package = inputs.continuwuity.packages.${pkgs.stdenv.hostPlatform.system}.default;
        settings.global = {
          # server
          server_name = "sgiath.dev";
          address = "0.0.0.0";
          port = 6167;
          admins_list = [
            "@sgiath:sgiath.dev"
          ];

          # registration
          allow_registration = true;
          registration_token = secrets.matrix_registration_token;

          # continuwuity
          new_user_displayname_suffix = "";
          allow_announcements_check = false;
          allow_legacy_media = false;

          # federation
          allow_public_room_directory_over_federation = true;
          lockdown_public_room_directory = true;

          # turn
          turn_secret = true;
          turn_secret_file = "/data/turn-secret";
          turn_uris = [
            "turn:turn.sgiath.dev:5349?transport=udp"
            "turn:turn.sgiath.dev:5350?transport=udp"
            "turn:turn.sgiath.dev:5349?transport=tcp"
            "turn:turn.sgiath.dev:5350?transport=tcp"
          ];

          trusted_servers = [
            "matrix.org"
            "nixos.org"
          ];

          well_known = {
            client = "https://matrix.sgiath.dev";
            server = "matrix.sgiath.dev:443";
            support_email = "matrix@sgiath.dev";
            support_mxid = "@sgiath:sgiath.dev";
          };
        };

        coturn = {
          enable = true;
          lt-cred-mech = true;
          use-auth-secret = true;
          static-auth-secret = secrets.turn-shared-secret;
          realm = "turn.sgiath.dev";
          relay-ips = [
            "193.165.30.198"
          ];
          no-tcp-relay = true;
          extraConfig = "
            cipher-list=\"HIGH\"
            no-loopback-peers
            no-multicast-peers
          ";
          secure-stun = true;
          cert = "/var/lib/acme/turn.sgiath.dev/fullchain.pem";
          pkey = "/var/lib/acme/turn.sgiath.dev/key.pem";
          min-port = 49152;
          max-port = 49999;
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

          "/_matrix/" = {
            proxyPass = "http://127.0.0.1:6167$request_uri";
          };
        };

        "matrix.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          # static files
          locations = {
            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:6167";
            };
          };
        };

        "turn.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;
        };
      };
    };

    security.acme.certs = {
      "turn.sgiath.dev" = {
        group = "turnserver";
        allowKeysForGroup = true;
        postRun = "systemctl reload nginx.service; systemctl restart coturn.service";
      };
    };
  };
}
