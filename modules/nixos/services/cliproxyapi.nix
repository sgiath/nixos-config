{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cliproxyapi;
  nebula = config.sgiath.nebula;
  host = "cliproxy.sgiath.dev";
  authDir = "/data/cliproxyapi";
in
{
  # CLIProxyAPI from the nixpkgs module, with the llm-agents package. Clients
  # authenticate with CLIPROXY_API_KEY, the shared key every host exports.
  # OAuth logins (and the KV store next to them) live in authDir on /data.
  # The module regenerates /var/lib/cliproxyapi/config.yaml from these
  # settings on every start, so management-panel edits last only until the
  # next restart; logins are files and persist.
  config = lib.mkMerge [
    { sgiath.nebula.services = [ "cliproxy" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      sops.secrets = {
        cliproxyapi_management.restartUnits = [ "cliproxyapi.service" ];
        cliproxy_api_key.restartUnits = [ "cliproxyapi.service" ];
      };

      services.cliproxyapi = {
        package = pkgs.llm-agents.cli-proxy-api;
        settings = {
          server.host = "127.0.0.1";
          oauth.auth-dir = authDir;
          access.api-keys = [ { _secret = config.sops.secrets.cliproxy_api_key.path; } ];
          # nginx connects from loopback, so the panel counts as local and
          # allow-remote stays off; the management key is still required.
          management.secret-key._secret = config.sops.secrets.cliproxyapi_management.path;
        };
      };

      # CLI logins run as the service user against the generated config:
      #   sudo -u cliproxyapi cli-proxy-api -config /var/lib/cliproxyapi/config.yaml -no-browser -claude-login
      environment.systemPackages = [ cfg.package ];

      systemd.tmpfiles.rules = [ "d ${authDir} 0700 cliproxyapi cliproxyapi -" ];
      systemd.services.cliproxyapi = {
        unitConfig.RequiresMountsFor = [ authDir ];
        serviceConfig.ReadWritePaths = [ authDir ];
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
          proxyPass = "http://127.0.0.1:${toString cfg.settings.server.port}";
          # Responses stream (SSE) and Codex uses websockets; long agent turns
          # and image/file uploads need generous limits.
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
            client_max_body_size 100m;
          '';
        };
      };
    })
  ];
}
