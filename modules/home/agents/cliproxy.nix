{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Pi and fx use CLIProxyAPI for inference with the CLIPROXY_API_KEY every
  # host exports; Claude Code is set up in claude.nix (sharing multiple Claude
  # subscriptions), while Codex, Grok, Antigravity, Muse and OpenCode 2 use
  # their native logins directly (opencode.nix keeps OpenCode on OpenCode Go
  # only). Pi uses Home Manager's mutableSettings; fx has no upstream module,
  # so activation merges the proxy part into its settings.json.
  url = config.sgiath.agents.cliproxyUrl;
  keyEnv = "CLIPROXY_API_KEY";
  catalog = import ./cliproxy-models.nix;
  personal = catalog.personal;
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
    programs.pi-coding-agent = {
      models = pi personal;
      settings = {
        defaultProvider = "cliproxy";
        defaultModel = defaults.model;
      };
    };

    home.activation.fxProxy = merge {
      path = ".fx/settings.json";
      overlay = {
        cliproxy = fx personal defaults.helper;
      };
      filter = ''
        .providers = ((.providers // {}) + $proxy)
        | .provider = "cliproxy"
        | .models.cliproxy |= (if . != null and (. as $m | $proxy.cliproxy.model_metadata | has($m))
            then . else "${defaults.model}" end)
      '';
    };
  };
}
