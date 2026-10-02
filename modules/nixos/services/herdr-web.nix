{ config, lib, ... }:
let
  cfg = config.services.herdr-web;
  nebula = config.sgiath.nebula;
  port = 7317;
  authConf = "/run/nginx/herdr-auth.conf";
  # PCs the web UI reaches over SSH as remote PCs (Settings -> Add PC, with
  # /run/secrets/herdr-web-<pc>-ssh-key as the key path). Each private key is
  # in secrets/vesta.yaml; its public half is secrets/herdr-web-<pc>.pub,
  # which the PC authorizes for logins from Vesta's overlay addresses only.
  remotePcs = [
    "ceres"
    "mac"
  ];
in
{
  options.services.herdr-web = {
    enable = lib.mkEnableOption "herdr-web-ui on the overlay (herdr.sgiath.dev; herdr and the web UI run as sgiath's user services)";
  };

  config = lib.mkMerge [
    { sgiath.nebula.services = [ "herdr" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      home-manager.users.sgiath.services.herdr-web = {
        enable = true;
        inherit port;
        environmentFile = config.sops.templates."herdr-web.env".path;
      };

      sops = {
        secrets = {
          # The web UI's shared token. Without one, the proxied address lets in
          # anyone until the first device is paired.
          herdr-web-token = {
            sopsFile = ../../../secrets/vesta.yaml;
            restartUnits = [ "nginx.service" ];
          };
        }
        // lib.genAttrs' remotePcs (pc: {
          name = "herdr-web-${pc}-ssh-key";
          value = {
            sopsFile = ../../../secrets/vesta.yaml;
            owner = "sgiath";
            mode = "0400";
          };
        });

        templates."herdr-web.env" = {
          owner = "sgiath";
          mode = "0400";
          content = ''
            HERDR_WEB_TOKEN=${config.sops.placeholder.herdr-web-token}
          '';
        };
      };

      # Nebula membership is the auth: nginx presents the token for every
      # overlay client, rendered at start from the systemd credential so it
      # never enters the store.
      systemd.services.nginx = {
        serviceConfig.LoadCredential = [
          "herdr-web-token:${config.sops.secrets.herdr-web-token.path}"
        ];
        preStart = lib.mkBefore ''
          umask 077
          printf 'proxy_set_header Authorization "Bearer %s";\n' \
            "$(cat "$CREDENTIALS_DIRECTORY/herdr-web-token")" \
            > ${authConf}
        '';
      };

      services.nginx.virtualHosts."herdr.sgiath.dev" = {
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

        # The server tells a proxied request from a local one by its Host and
        # X-Forwarded-* headers; the global recommendedProxySettings sends them,
        # so this location must keep it.
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          # Terminal output and agent events stream over one websocket.
          proxyWebsockets = true;
          extraConfig = ''
            include ${authConf};
            proxy_buffering off;
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
            # Pasted images: up to 8 MiB, sent base64-encoded in JSON.
            client_max_body_size 16m;
          '';
        };
      };
    })
  ];
}
