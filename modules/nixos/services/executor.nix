{ config, lib, ... }:
let
  cfg = config.services.executor;
  nebula = config.sgiath.nebula;
  # Upstream ships only a Docker image (Bun workspace monorepo, no Nix packaging).
  # Pinned rather than `latest` so every deploy is recorded and a bump restarts
  # the container; scripts/update-executor.sh (run by update-inputs.sh) bumps it.
  version = "1.6.10";
  # The distroless image runs as this fixed uid; it must own the data volume.
  uid = 65532;
  port = 4788;
  host = "executor.sgiath.dev";
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
