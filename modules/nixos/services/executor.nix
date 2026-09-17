{ config, lib, ... }:
let
  cfg = config.services.executor;
  nebula = config.sgiath.nebula;
  # Upstream ships only a Docker image (Bun workspace monorepo, no Nix packaging).
  # Bump the tag manually; `latest` would silently change the deployed version.
  version = "1.6.8";
  # The distroless image runs as this fixed uid; it must own the data volume.
  uid = 65532;
  port = 4788;
  host = "executor.sgiath.dev";
  # FIXME: 1.6.8 declares only the authorization_code grant in its Client ID
  # Metadata Document; Shortcut rejects the consent because it issues refresh
  # tokens. Fixed upstream after 1.6.8 (UsefulSoftwareCo/executor#1974). Drop
  # this override and the location serving it once `version` includes it.
  cimdPath = "/api/oauth/client-id-metadata/default.json";
  cimdDocument = builtins.toJSON {
    client_id = "https://${host}${cimdPath}";
    client_name = "Executor";
    client_uri = "https://${host}";
    redirect_uris = [ "https://${host}/api/oauth/callback" ];
    grant_types = [
      "authorization_code"
      "refresh_token"
    ];
    response_types = [ "code" ];
    token_endpoint_auth_method = "none";
    application_type = "web";
  };
in
{
  options.services.executor = {
    enable = lib.mkEnableOption "Executor MCP server (self-hosted Docker image)";
  };

  config = lib.mkMerge [
    { sgiath.nebula.services = [ "executor" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      virtualisation.oci-containers = {
        backend = lib.mkDefault "docker";
        containers.executor = {
          image = "ghcr.io/rhyssullivan/executor-selfhost:${version}";
          ports = [ "127.0.0.1:${toString port}:${toString port}" ];
          # SQLite database plus the generated BETTER_AUTH_SECRET / EXECUTOR_SECRET_KEY.
          volumes = [ "/data/executor:/data" ];
          environment = {
            # Must match the URL loaded in the browser or logins fail with invalid-origin.
            EXECUTOR_WEB_BASE_URL = "https://${host}";
          };
        };
      };

      systemd.tmpfiles.rules = [
        "d /data/executor 0750 ${toString uid} ${toString uid} -"
      ];

      services.nginx.virtualHosts.${host} = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # Overlay only, except the OAuth Client ID Metadata Document: providers
        # that support CIMD (Notion, Shortcut) fetch it from the public internet
        # to learn the redirect URI, and Executor always prefers CIMD over DCR
        # when the provider advertises it. The document is public by design
        # (client name and callback URL). Needs a public DNS record to matter.
        extraConfig = ''
          allow ${nebula.cidr4};
          allow ${nebula.cidr6};
          deny all;
        '';

        locations = {
          "^~ /api/oauth/client-id-metadata/" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            extraConfig = "allow all;";
          };

          "= ${cimdPath}".extraConfig = ''
            allow all;
            default_type application/json;
            return 200 '${cimdDocument}';
          '';

          "/" = {
            proxyPass = "http://127.0.0.1:${toString port}";
            proxyWebsockets = true;
            # /mcp is streamable HTTP (SSE): long-lived, must not be buffered.
            extraConfig = ''
              proxy_buffering off;
              proxy_read_timeout 1h;
            '';
          };
        };
      };

      systemd.services.nginx.after = [ "docker-executor.service" ];
    })
  ];
}
