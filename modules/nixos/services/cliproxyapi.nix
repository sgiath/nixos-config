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

  # API-key upstreams. CLIProxyAPI does not discover their models, so each
  # one is listed, and exposed as <name>/<model> so it never shares a name
  # with a model of a logged-in account (requests would round-robin between
  # them). Both upstreams are called as OpenAI chat completions; CLIProxyAPI
  # translates Responses and Messages requests.
  compat =
    {
      name,
      base-url,
      secret,
      models,
      headers ? { },
    }:
    {
      inherit name base-url headers;
      keys = [ { api-key._secret = config.sops.secrets.${secret}.path; } ];
      models = map (model: {
        name = model;
        alias = "${name}/${model}";
      }) models;
    };
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
        opencode_go_api_key = {
          sopsFile = ../../../secrets/vesta.yaml;
          restartUnits = [ "cliproxyapi.service" ];
        };
        litellm_api_key = {
          sopsFile = ../../../secrets/vesta.yaml;
          restartUnits = [ "cliproxyapi.service" ];
        };
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

          api-keys.openai-compatibility = [
            # OpenCode Go subscription (opencode.ai/console API key). Go asks
            # for an identifying User-Agent and a stable session ID per
            # conversation; pass through whichever one the client sends.
            # Free, contributor and DeepSeek models need workspace privacy
            # settings and are left out.
            (compat {
              name = "opencode-go";
              base-url = "https://opencode.ai/inference/go/openai/v1";
              secret = "opencode_go_api_key";
              headers = {
                "User-Agent" = "cliproxyapi/${cfg.package.version}";
                "x-opencode-session" = "$x-opencode-session";
                "Session_id" = "$Session_id";
                "Session-Id" = "$Session-Id";
                "X-Claude-Code-Session-Id" = "$X-Claude-Code-Session-Id";
              };
              models = [
                "glm-5.3-flash"
                "glm-5.3"
                "glm-5.2"
                "kimi-k3.1-pro"
                "kimi-k3"
                "kimi-k2.7-code"
                "longcat-2.0"
                "mimo-v2.6-flash"
                "mimo-v2.6-pro"
                "mimo-v2.5"
                "mimo-v2.5-pro"
                "minimax-m3.1-flash"
                "minimax-m3"
                "hy4"
                "hy4-preview"
                "hy3"
                "step-5-preview"
                "grok-4.7"
                "gpt-6-luna"
                "gpt-5.6-luna"
                "claude-haiku-5-5"
                "qwen3.8-max"
                "qwen3.8-flash"
                "qwen3.7-plus"
                "gemini-4-argon"
              ];
            })
            # Remote's LiteLLM gateway. Only the chat models this key may call
            # directly (`direct_access` in /v1/model/info); the others 403.
            (compat {
              name = "litellm";
              base-url = "https://ai-gateway-internal.eu-west-1.remote.com/v1";
              secret = "litellm_api_key";
              models = [
                "gpt-6.1-sol"
                "gpt-6.1-terra"
                "gpt-6-astra"
                "gpt-6-luna"
                "gpt-5.6-luna"
                "gemini-4-argon"
                "gemini-3.8-flash"
                "kimi-k3.1-pro"
              ];
            })
          ];
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
