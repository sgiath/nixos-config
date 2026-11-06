{
  config,
  lib,
  pkgs,
  ...
}:
let
  # OpenCode 2, Pi, fx and Grok use CLIProxyAPI for inference with the
  # CLIPROXY_API_KEY every host exports; Claude Code and Codex are set up in
  # claude.nix and modules/nixos/common/codex.nix, Muse keeps its native
  # Meta login (the proxy has no Muse model catalog). Each tool rewrites its
  # own config, so activation merges the proxy part into it and resets the
  # default model only when it no longer points at the proxy. The tools'
  # saved native logins stay in place.
  url = config.sgiath.agents.cliproxyUrl;
  keyEnv = "CLIPROXY_API_KEY";
  models = import ./cliproxy-models.nix;
  ids = map (m: m.id) models;
  byId = f: lib.listToAttrs (map (m: lib.nameValuePair m.id (f m)) models);

  # Proxy models answer helper calls (titles, summaries, web search) so no
  # tool falls back to its native account for them.
  defaultModel = "gpt-6.1-sol";
  helperModel = "gpt-6-luna";

  jq = lib.getExe pkgs.jq;
  # FIXME: the TOML round trip drops comments and cannot carry TOML dates
  # (the merge then leaves the file alone); fine while Grok's config has none.
  tomlJson = pkgs.writeShellScript "toml-json" ''
    exec ${lib.getExe (pkgs.python3.withPackages (ps: [ ps.tomli-w ]))} -c '
    import json, sys, tomllib, tomli_w
    if sys.argv[1] == "to-json":
        json.dump(tomllib.loads(sys.stdin.read()), sys.stdout)
    else:
        sys.stdout.write(tomli_w.dumps(json.load(sys.stdin)))
    ' "$1"
  '';

  # Rewrites ~/<path> with `filter` applied, only when that changes it, and
  # leaves the file alone when it cannot be parsed. $proxy in the filter is
  # `overlay`; `toml` files go through JSON.
  merge =
    {
      path,
      overlay,
      filter,
      toml ? false,
    }:
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/${path}"
      old=$(cat "$f" 2>/dev/null || true)
      if new=$(set -o pipefail; printf '%s' "$old" ${lib.optionalString toml "| ${tomlJson} to-json"} \
        | ${jq} -s --argjson proxy ${lib.escapeShellArg (builtins.toJSON overlay)} \
          ${lib.escapeShellArg "(.[0] // {}) | ${filter}"} \
        ${lib.optionalString toml "| ${tomlJson} from-json"}); then
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
  opencode = {
    name = "CLIProxyAPI";
    package = opencodePackage.responses;
    settings.baseURL = "${url}/v1";
    models = byId (m: {
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
  };

  piApi = {
    messages = "anthropic-messages";
    responses = "openai-responses";
    chat = "openai-completions";
  };
  pi.providers.cliproxy = {
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

  fx = {
    protocol = "openai-chat-completions";
    base_url = "${url}/v1";
    auth = {
      type = "bearer";
      env = keyEnv;
    };
    reviewer_model = helperModel;
    model_metadata = byId (m: {
      context_window = m.context;
      max_output_tokens = m.output;
      supports_tool_use = true;
      supports_vision = lib.elem "image" m.input;
    });
  };

  grokBackend = {
    messages = "messages";
    responses = "responses";
    chat = "chat_completions";
  };
  grok = {
    keys = ids;
    model = byId (m: {
      inherit (m) name;
      model = m.id;
      base_url = "${url}/v1";
      env_key = keyEnv;
      api_backend = grokBackend.${m.protocol};
      context_window = m.context;
      max_completion_tokens = m.output;
    });
  };
  # Keep a proxy model the user picked; replace anything else.
  grokPick = slot: fallback: ".${slot} |= (if IN($proxy.keys[]) then . else \"${fallback}\" end)";
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    # Pi rewrites settings.json but only reads models.json.
    home.file.".pi/agent/models.json".text = builtins.toJSON pi;

    home.activation = {
      opencodeProxy = merge {
        path = ".config/opencode/opencode.json";
        overlay = opencode;
        # Proxy only: deny every provider, allow cliproxy, keep the rest of
        # the user's policies after them.
        filter = ''
          .providers.cliproxy = $proxy
          | .model |= (if type == "string" and startswith("cliproxy/") then . else "cliproxy/${defaultModel}" end)
          | .policies = [
              {action: "provider.use", resource: "*", effect: "deny"},
              {action: "provider.use", resource: "cliproxy", effect: "allow"}
            ] + [(.policies // [])[] | select(.action != "provider.use" or (.resource | IN("*", "cliproxy") | not))]
        '';
      };

      piProxy = merge {
        path = ".pi/agent/settings.json";
        overlay = { };
        filter = ''
          if .defaultProvider == "cliproxy" then . else .defaultProvider = "cliproxy" | .defaultModel = "${defaultModel}" end
        '';
      };

      fxProxy = merge {
        path = ".fx/settings.json";
        overlay = fx;
        filter = ''
          .providers.cliproxy = $proxy
          | .provider = "cliproxy"
          | .models.cliproxy |= (if . == null then "${defaultModel}" else . end)
        '';
      };

      grokProxy = merge {
        path = ".grok/config.toml";
        toml = true;
        overlay = grok;
        filter = ''
          .model = ((.model // {}) + $proxy.model)
          | .models.allowed_models = $proxy.keys
          | .models |= (${grokPick "default" "grok-4.7"}
              | ${grokPick "web_search" helperModel}
              | ${grokPick "session_summary" helperModel}
              | ${grokPick "image_description" helperModel}
              | ${grokPick "prompt_suggestion" helperModel})
          | .ui |= ((. // {}) | ${grokPick "fork_secondary_model" defaultModel})
        '';
      };
    };
  };
}
