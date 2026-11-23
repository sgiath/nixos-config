{
  config,
  lib,
  pkgs,
  ...
}:
let
  # OpenCode 2, Pi and fx use CLIProxyAPI for inference with the
  # CLIPROXY_API_KEY every host exports; Claude Code is set up in claude.nix
  # (sharing multiple Claude subscriptions), while Codex, Grok, Antigravity
  # and Muse use their native logins directly. Each tool below rewrites its
  # own config, so activation merges the proxy part into it and resets the
  # default model only when it no longer points at the proxy.
  url = config.sgiath.agents.cliproxyUrl;
  keyEnv = "CLIPROXY_API_KEY";
  catalog = import ./cliproxy-models.nix;
  personal = catalog.personal;
  ids = map (m: m.id);
  byId = models: f: lib.listToAttrs (map (m: lib.nameValuePair m.id (f m)) models);

  # Proxy models answer helper calls (titles, summaries, web search,
  # permission review) so no tool falls back to its native account.
  defaults = {
    model = "gpt-6.2-sol";
    helper = "gpt-6-luna";
  };

  jq = lib.getExe pkgs.jq;

  # Rewrites ~/<path> with `filter` applied, only when that changes it, and
  # leaves the file alone when it cannot be parsed. $proxy in the filter is
  # `overlay`.
  merge =
    {
      path,
      overlay,
      filter,
    }:
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/${path}"
      old=$(cat "$f" 2>/dev/null || true)
      if new=$(set -o pipefail; printf '%s' "$old" \
        | ${jq} -s --argjson proxy ${lib.escapeShellArg (builtins.toJSON overlay)} \
          ${lib.escapeShellArg "(.[0] // {}) | ${filter}"}); then
        if [ "$new" != "$old" ]; then
          run mkdir -p "$(dirname "$f")"
          run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
        fi
      else
        echo "cliproxy: cannot merge the proxy settings into $f; left unchanged" >&2
      fi
    '';

  opencodePackage = {
    messages = "@opencode/ai/providers/anthropic-compatible";
    responses = "@opencode/ai/providers/openai-compatible-responses";
    chat = "@opencode/ai/providers/openai-compatible";
  };
  opencodeModels =
    models:
    byId models (m: {
      inherit (m) name;
      package = opencodePackage.${m.protocol};
      # The Messages transport sends authToken as a bearer and apiKey as
      # x-api-key; it rejects both at once.
      settings.${if m.protocol == "messages" then "authToken" else "apiKey"} = "{env:${keyEnv}}";
      limit = { inherit (m) context output; };
      capabilities.reasoning =
        if m.effort == [ ] then
          { supported = false; }
        else
          {
            supported = true;
            inherit (m) effort;
          };
    });
  opencode = {
    name = "CLIProxyAPI";
    package = opencodePackage.responses;
    settings.baseURL = "${url}/v1";
    models = opencodeModels personal;
  };

  piApi = {
    messages = "anthropic-messages";
    responses = "openai-responses";
    chat = "openai-completions";
  };
  pi = models: {
    providers.cliproxy = {
      baseUrl = "${url}/v1";
      api = piApi.responses;
      apiKey = "$" + keyEnv;
      authHeader = true;
      models = map (
        m:
        {
          inherit (m) id name input;
          api = piApi.${m.protocol};
          reasoning = m.effort != [ ];
          contextWindow = m.context;
          maxTokens = m.output;
        }
        # Pi's Messages transport appends /v1 itself.
        // lib.optionalAttrs (m.protocol == "messages") { baseUrl = url; }
      ) models;
    };
  };
  # Each tool keeps the proxy model the user picked while the catalog still
  # has it; anything else (another provider, a retired model) gets the default.
  piSettings = model: ''
    if .defaultProvider == "cliproxy" and ((.defaultModel // "") | IN($proxy.keys[]))
    then . else .defaultProvider = "cliproxy" | .defaultModel = "${model}" end
  '';

  # fx takes the permission reviewer from the provider.
  fx = models: reviewer: {
    protocol = "openai-chat-completions";
    base_url = "${url}/v1";
    auth = {
      type = "bearer";
      env = keyEnv;
    };
    reviewer_model = reviewer;
    model_metadata = byId models (m: {
      context_window = m.context;
      max_output_tokens = m.output;
      supports_tool_use = true;
      supports_vision = lib.elem "image" m.input;
    });
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    # Pi rewrites settings.json but only reads models.json.
    home.file.".pi/agent/models.json".text = builtins.toJSON (pi personal);

    home.activation = {
      opencodeProxy = merge {
        path = ".config/opencode/opencode.json";
        overlay = opencode;
        # Proxy only: deny every provider, allow cliproxy, keep the rest of
        # the user's policies after them. The native OpenAI/ChatGPT provider
        # plugins would still refresh their saved logins at startup.
        filter = ''
          .providers.cliproxy = $proxy
          | .update = "disable"
          | .share = "disabled"
          | .plugins = ((.plugins // []) - ["-opencode.provider.openai", "-opencode.provider.chatgpt"]
              + ["-opencode.provider.openai", "-opencode.provider.chatgpt"])
          | .model |= (if type == "string" and startswith("cliproxy/") and (ltrimstr("cliproxy/") as $m | $proxy.models | has($m))
              then . else "cliproxy/${defaults.model}" end)
          | .policies = [
              {action: "provider.use", resource: "*", effect: "deny"},
              {action: "provider.use", resource: "cliproxy", effect: "allow"}
            ] + [(.policies // [])[] | select(.action != "provider.use" or (.resource | IN("*", "cliproxy") | not))]
        '';
      };

      piProxy = merge {
        path = ".pi/agent/settings.json";
        overlay.keys = ids personal;
        filter = piSettings defaults.model;
      };

      fxProxy = merge {
        path = ".fx/settings.json";
        overlay = {
          cliproxy = fx personal defaults.helper;
        };
        filter = ''
          .providers = ((.providers // {}) + $proxy)
          | del(.providers["cliproxy-remote"], .models["cliproxy-remote"])
          | .provider = "cliproxy"
          | .models.cliproxy |= (if . != null and (. as $m | $proxy.cliproxy.model_metadata | has($m))
              then . else "${defaults.model}" end)
        '';
      };
    };
  };
}
