{
  config,
  lib,
  pkgs,
  inputs,
  utils,
  ...
}:
{
  options.services.matrix.enable = lib.mkEnableOption "matrix server";

  config = lib.mkIf (config.sgiath.roles.server.enable && config.services.matrix.enable) {
    sops.secrets = {
      matrix_registration_token.restartUnits = [ "continuwuity.service" ];
      turn-shared-secret.restartUnits = [
        "continuwuity.service"
        "coturn.service"
        "livekit.service"
      ];
    };
    systemd.services = {
      continuwuity.serviceConfig.LoadCredential = [
        "registration-token:${config.sops.secrets.matrix_registration_token.path}"
        "turn-secret:${config.sops.secrets.turn-shared-secret.path}"
      ];
      coturn.serviceConfig.LoadCredential = [
        "turn-secret:${config.sops.secrets.turn-shared-secret.path}"
      ];
      livekit = {
        serviceConfig = {
          LoadCredential = [ "turn-secret:${config.sops.secrets.turn-shared-secret.path}" ];
          RuntimeDirectory = "livekit";
          RuntimeDirectoryMode = "0700";
          ExecStart = lib.mkForce (
            utils.escapeSystemdExecArgs [
              (lib.getExe config.services.livekit.package)
              "--config=/run/livekit/config.json"
              "--key-file=/run/credentials/livekit.service/livekit-secrets"
            ]
          );
        };
        preStart = ''
          umask 077
          ${pkgs.jq}/bin/jq --rawfile secret "$CREDENTIALS_DIRECTORY/turn-secret" \
            '.rtc.turn_servers |= map(.secret = $secret)' \
            ${
              (pkgs.formats.json { }).generate "livekit-public.json" (
                lib.filterAttrsRecursive (_: value: value != null) config.services.livekit.settings
              )
            } > /run/livekit/config.json
        '';
      };
    };

    environment.systemPackages = with pkgs; [
      livekit
    ];

    services = {
      matrix-continuwuity = {
        enable = true;
        package = inputs.continuwuity.packages.${pkgs.stdenv.hostPlatform.system}.default;
        settings.global = {
          # server
          server_name = "sgiath.dev";
          address = [
            "127.0.0.1"
            "::1"
          ];
          port = [ 6167 ];
          admins_list = [
            "@sgiath:sgiath.dev"
          ];

          # registration
          allow_registration = true;
          registration_token_file = "/run/credentials/continuwuity.service/registration-token";

          # continuwuity
          new_user_displayname_suffix = "";
          allow_announcements_check = false;
          allow_legacy_media = false;

          # federation
          allow_public_room_directory_over_federation = true;
          lockdown_public_room_directory = true;

          # turn
          turn_secret_file = "/run/credentials/continuwuity.service/turn-secret";
          turn_uris = [
            "turn:turn.sgiath.dev:3478?transport=udp"
            "turn:turn.sgiath.dev:3478?transport=tcp"
            "turns:turn.sgiath.dev:5349?transport=udp"
            "turns:turn.sgiath.dev:5349?transport=tcp"
          ];

          trusted_servers = [
            "matrix.org"
            "nixos.org"
            "matrix.crazyeggstaging.com"
            "matrix.crazyegg.com"
          ];

          well_known = {
            client = "https://matrix.sgiath.dev";
            server = "matrix.sgiath.dev:443";
            support_email = "matrix@sgiath.dev";
            support_mxid = "@sgiath:sgiath.dev";
            rtc_focus_server_urls = [
              {
                type = "livekit";
                livekit_service_url = "https://matrix-rtc.sgiath.dev";
              }
            ];
          };
        };
      };

      coturn = {
        enable = true;
        lt-cred-mech = true;
        use-auth-secret = true;
        static-auth-secret-file = "/run/credentials/coturn.service/turn-secret";
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

      lk-jwt-service = {
        enable = true;
        port = 7882;
        keyFile = "/data/matrix-rtc";
        livekitUrl = "wss://matrix-rtc.sgiath.dev";
      };

      livekit = {
        enable = true;
        keyFile = "/data/matrix-rtc";
        settings = {
          port = 7880;
          rtc = {
            node_ip = "193.165.30.198";
            tcp_port = 7881;
            port_range_start = 50000;
            port_range_end = 51000;
            turn_servers = [
              {
                host = "turn.sgiath.dev";
                port = 3478;
                protocol = "tcp";
              }
              {
                host = "turn.sgiath.dev";
                port = 3478;
                protocol = "udp";
              }
              {
                host = "turn.sgiath.dev";
                port = 5349;
                protocol = "tls";
              }
            ];
          };
        };
      };

      nginx.virtualHosts = {
        # sgiath.dev itself (incl. /.well-known/matrix/*) is served by Cloudflare
        # Workers from the sgiath.dev site repo.
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

        "matrix-rtc.sgiath.dev" = {
          # SSL
          onlySSL = true;
          kTLS = true;

          # ACME
          enableACME = true;
          acmeRoot = null;

          locations = {
            "~ ^/(sfu/get|healthz|get_token)" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:7882";
            };

            "/" = {
              proxyWebsockets = true;
              proxyPass = "http://127.0.0.1:7880";
            };
          };
        };
      };
    };

    systemd.services.nginx.after = [ "continuwuity.service" ];

    users.users.turnserver.extraGroups = [ "nginx" ];
    security.acme.certs = {
      "turn.sgiath.dev" = {
        postRun = "systemctl reload nginx.service; systemctl restart coturn.service";
      };
    };
  };
}
