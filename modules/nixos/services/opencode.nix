{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.opencode;
  nebula = config.sgiath.nebula;
  host = "opencode.sgiath.dev";
  port = 4096;
  # OpenCode 2 always protects its server with HTTP basic auth (username
  # `opencode`); the password is either generated per start or taken from
  # OPENCODE_SERVER_PASSWORD. Nebula membership is the real auth here, so nginx
  # injects the credential and clients on the overlay never see a login. The
  # header is rendered at nginx start from the systemd credential so the
  # password never enters the store.
  authConf = "/run/nginx/opencode-auth.conf";
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "OpenCode 2 server (sessions run on this host as sgiath)";
  };

  config = lib.mkMerge [
    { sgiath.nebula.services = [ "opencode" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      sops.secrets.opencodePassword.restartUnits = [
        "opencode.service"
        "nginx.service"
      ];

      systemd.services = {
        opencode = {
          description = "OpenCode 2 server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          # Tool execution happens in this unit: expose the user's profile so
          # agent shells see the same commands as an interactive login.
          path = [ "/etc/profiles/per-user/sgiath" ];

          serviceConfig = {
            User = "sgiath";
            Group = "users";
            WorkingDirectory = "/home/sgiath";
            LoadCredential = [ "password:${config.sops.secrets.opencodePassword.path}" ];
            Restart = "always";
            RestartSec = 5;
          };

          script = ''
            OPENCODE_SERVER_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/password")"
            export OPENCODE_SERVER_PASSWORD
            exec ${lib.getExe pkgs.llm-agents.opencode2} serve \
              --hostname 127.0.0.1 --port ${toString port}
          '';
        };

        nginx = {
          after = [ "opencode.service" ];
          serviceConfig.LoadCredential = [
            "opencode-password:${config.sops.secrets.opencodePassword.path}"
          ];
          preStart = lib.mkBefore ''
            umask 077
            printf 'proxy_set_header Authorization "Basic %s";\n' \
              "$(printf 'opencode:%s' "$(cat "$CREDENTIALS_DIRECTORY/opencode-password")" | ${pkgs.coreutils}/bin/base64 -w0)" \
              > ${authConf}
          '';
        };
      };

      services.nginx.virtualHosts.${host} = {
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
          proxyPass = "http://127.0.0.1:${toString port}";
          # PTY/terminal streams are websockets; /api/event is a long-lived SSE
          # stream that must not be buffered.
          proxyWebsockets = true;
          extraConfig = ''
            include ${authConf};
            proxy_buffering off;
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
            client_max_body_size 100m;
          '';
        };
      };
    })
  ];
}
