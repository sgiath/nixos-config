{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.services.browse;
  nebula = config.sgiath.nebula;
  browsePkg = pkgs.${namespace}.browse;
  host = "browse.sgiath.dev";
  relayPort = 19988;
  mcpPort = 19989;
  tokenFile = "/home/sgiath/.local/share/browse/mcp-token";

  bridgePython = pkgs.python3.withPackages (ps: [
    ps.mcp
    ps.starlette
    ps.uvicorn
  ]);
  testPython = pkgs.python3.withPackages (ps: [
    ps.httpx
    ps.mcp
    ps.starlette
    ps.uvicorn
  ]);

  # Streamable HTTP MCP bridge for `browse mcp`; its tests run in the build.
  mcpBridge = pkgs.runCommandLocal "browse-mcp-bridge" { } ''
    PYTHONDONTWRITEBYTECODE=1 ${lib.getExe testPython} -I -m unittest discover \
      -s ${./browse} -t ${./browse}
    install -Dm755 ${./browse/mcp_bridge.py} $out/bin/browse-mcp
    sed -i '1c#!${lib.getExe bridgePython} -I' $out/bin/browse-mcp
  '';
in
{
  options.services.browse = {
    enable = lib.mkEnableOption "Browse remote relay and Streamable HTTP MCP bridge";
  };

  config = lib.mkMerge [
    { sgiath.nebula.services = [ "browse" ]; }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      # Keep the `browse` CLI on PATH so `browse pair`, `browse pair --list`
      # and `browse status` run directly against this host's relay as sgiath.
      environment.systemPackages = [ browsePkg ];

      systemd.services = {
        browse-relay = {
          description = "Browse remote browser relay";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          # BindsTo stops browse-mcp when the relay crashes; Upholds brings
          # browse-mcp back up once systemd restarts browse-relay.
          unitConfig.Upholds = "browse-mcp.service";

          environment = {
            HOME = "/home/sgiath";
            OPENCODE_BROWSER_PORT = toString relayPort;
            # Executor already wraps tools in its own code mode; expose plain
            # browse tools (navigate, snapshot, click, screenshot, ...) instead
            # of browse's nested JS execute tool.
            OPENCODE_BROWSER_TOOLS = "plain";
          };

          # `browse serve` only supports 127.0.0.1 or 0.0.0.0; non-loopback
          # peers can reach only `/extension` (ECDH + mutual HMAC pairing),
          # while all HTTP control/tool routes stay loopback-only.
          preStart = ''
            cfg="/home/sgiath/.config/browse/config.json"
            mkdir -p -m 0700 "$(dirname "$cfg")"
            current='{}'
            if [[ -s $cfg ]]; then
              current=$(cat "$cfg")
            fi
            updated=$(${lib.getExe pkgs.jq} '.hostname = "0.0.0.0"' <<<"$current")
            tmp=$(mktemp "$cfg.XXXXXX")
            trap '[[ -z ''${tmp-} ]] || rm -f -- "$tmp"' EXIT
            printf '%s\n' "$updated" >"$tmp"
            chmod 600 "$tmp"
            mv -f "$tmp" "$cfg"
            tmp=
          '';

          serviceConfig = {
            User = "sgiath";
            Group = "users";
            WorkingDirectory = "/home/sgiath";
            ExecStart = "${lib.getExe browsePkg} serve";
            # Wait until /version answers so browse-mcp connects to this relay
            # instead of spawning a detached managed relay on startup.
            ExecStartPost = pkgs.writeShellScript "browse-relay-ready" ''
              for _ in $(seq 1 60); do
                if ${lib.getExe pkgs.curl} -fsS --max-time 1 http://127.0.0.1:${toString relayPort}/version >/dev/null 2>&1; then
                  exit 0
                fi
                sleep 0.25
              done
              echo "browse-relay did not become ready on 127.0.0.1:${toString relayPort}" >&2
              exit 1
            '';
            Restart = "always";
            RestartSec = 5;
            UMask = "0077";
          };
        };

        browse-mcp = {
          description = "Browse Streamable HTTP MCP bridge";
          wantedBy = [ "multi-user.target" ];
          after = [ "browse-relay.service" ];
          bindsTo = [ "browse-relay.service" ];
          partOf = [ "browse-relay.service" ];

          environment = {
            HOME = "/home/sgiath";
            OPENCODE_BROWSER_PORT = toString relayPort;
            OPENCODE_BROWSER_TOOLS = "plain";
            BROWSE_BIN = lib.getExe browsePkg;
            BROWSE_MCP_HOST = "127.0.0.1";
            BROWSE_MCP_PORT = toString mcpPort;
            BROWSE_MCP_TOKEN_FILE = tokenFile;
          };

          serviceConfig = {
            User = "sgiath";
            Group = "users";
            WorkingDirectory = "/home/sgiath";
            ExecStart = lib.getExe' mcpBridge "browse-mcp";
            Restart = "always";
            RestartSec = 5;
            UMask = "0077";
          };
        };

        nginx.after = [ "browse-mcp.service" ];
      };

      services.nginx.virtualHosts.${host} = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # Overlay peers plus the local Docker bridge so Executor's container
        # can reach https://browse.sgiath.dev/mcp; Bearer auth is enforced by
        # browse-mcp itself. Cap request size to browse-relay's 16 MiB limit
        # and stream bodies straight through so unauthenticated requests are
        # rejected before nginx buffers them to disk.
        extraConfig = ''
          allow ${nebula.cidr4};
          allow ${nebula.cidr6};
          allow 172.17.0.0/16;
          deny all;
          client_max_body_size 16m;
        '';

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString mcpPort}";
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_read_timeout 10m;
            proxy_send_timeout 10m;
          '';
        };
      };
    })
  ];
}
