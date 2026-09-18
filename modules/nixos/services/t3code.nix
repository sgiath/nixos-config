{ config, lib, ... }:
let
  cfg = config.services.t3code;
  nebula = config.sgiath.nebula;
  port = 3773;
  # T3 Code has no unauthenticated mode: every request needs a paired browser
  # session or a bearer token, and the web app cannot add an environment
  # without a pairing code. Nebula membership is the real auth here, so nginx
  # injects a long-lived bearer (`t3 auth session issue --ttl 3650d`, issued
  # on the machine that runs the server, stored in secrets/vesta.yaml) and
  # drops any stale browser cookie, which would otherwise take precedence.
  # The token is rendered at nginx start from the systemd credential so it
  # never enters the store; wiping ~/.t3/userdata on a host invalidates it.
  #
  # There is no worker/node mode either: each machine that should run agents
  # runs its own server (the HM user service) and appears as a separate
  # environment. Vesta's own server is t3.sgiath.dev; the peers below get
  # t3-<peer>.sgiath.dev proxied to their overlay address so the HTTPS web
  # app can add them ("Add environment" with a `t3 pair` code from that
  # peer, once per browser).
  remotes = [ "ceres" ];
  environments = {
    t3 = {
      upstream = "http://127.0.0.1:${toString port}";
      secret = "t3code-vesta-token";
    };
  }
  // lib.genAttrs' remotes (peer: {
    name = "t3-${peer}";
    value = {
      upstream = "http://${nebula.peers.${peer}.ip4}:${toString port}";
      secret = "t3code-${peer}-token";
    };
  });
  authConf = name: "/run/nginx/${name}-auth.conf";
in
{
  options.services.t3code = {
    enable = lib.mkEnableOption "T3 Code web app on the overlay (t3.sgiath.dev; server runs as sgiath's user service)";
  };

  config = lib.mkMerge [
    { sgiath.nebula.services = lib.attrNames environments; }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      home-manager.users.sgiath.services.t3code.enable = true;

      sops.secrets = lib.mapAttrs' (
        _: env:
        lib.nameValuePair env.secret {
          sopsFile = ../../../secrets/vesta.yaml;
          restartUnits = [ "nginx.service" ];
        }
      ) environments;

      systemd.services.nginx = {
        serviceConfig.LoadCredential = lib.mapAttrsToList (
          _: env: "${env.secret}:${config.sops.secrets.${env.secret}.path}"
        ) environments;
        preStart = lib.mkBefore (
          lib.concatStrings (
            lib.mapAttrsToList (name: env: ''
              umask 077
              printf 'proxy_set_header Authorization "Bearer %s";\n' \
                "$(cat "$CREDENTIALS_DIRECTORY/${env.secret}")" \
                > ${authConf name}
            '') environments
          )
        );
      };

      services.nginx.virtualHosts = lib.mapAttrs' (
        name: env:
        lib.nameValuePair "${name}.sgiath.dev" {
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
            proxyPass = env.upstream;
            # /ws is a long-lived websocket carrying every agent event.
            proxyWebsockets = true;
            extraConfig = ''
              include ${authConf name};
              proxy_set_header Cookie "";
              proxy_buffering off;
              proxy_read_timeout 1h;
              proxy_send_timeout 1h;
              client_max_body_size 100m;
            '';
          };
        }
      ) environments;
    })
  ];
}
