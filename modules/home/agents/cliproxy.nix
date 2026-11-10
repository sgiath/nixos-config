{
  config,
  lib,
  pkgs,
  ...
}:
let
  # OpenCode 2, Pi, fx and Grok use CLIProxyAPI for inference with the
  # CLIPROXY_API_KEY every host exports; Claude Code and Codex are set up in
  # claude.nix, codex.nix and modules/nixos/common/codex.nix, Muse keeps its
  # native Meta login (the proxy has no Muse model catalog). Each tool
  # rewrites its own config, so activation merges the proxy part into it and
  # resets the default model only when it no longer points at the proxy. The
  # tools' saved native logins stay in place.
  #
  # Remote projects call `use remote_agents` from their .envrc. It points
  # every tool at remote/<model> (the Remote Claude login and Remote
  # LiteLLM): Claude Code through its model variables, Codex through the
  # remote profile (codex.nix), OpenCode through an extra config file, fx
  # through a second provider, and Pi and Grok through their own config
  # directories under ~/.config/remote-agents (no native login there).
  url = config.sgiath.agents.cliproxyUrl;
  keyEnv = "CLIPROXY_API_KEY";
  catalog = import ./cliproxy-models.nix;
  personal = catalog.personal;
  remote =
    map
      (
        m:
        m
        // {
          id = "remote/${m.id}";
          name = "${m.name} (Remote)";
        }
      )
      (
        lib.filter (
          m:
          lib.elem m.id [
            "claude-opus-5-5"
            "claude-sonnet-5-5"
            "claude-haiku-5-5"
            "claude-fable-5-1"
            "gpt-6.1-sol"
            "gpt-6.1-terra"
            "gpt-6-astra"
            "gpt-6-luna"
          ]
        ) personal
      )
    ++ catalog.remoteOnly;
  ids = map (m: m.id);
  byId = models: f: lib.listToAttrs (map (m: lib.nameValuePair m.id (f m)) models);

  # Proxy models answer helper calls (titles, summaries, web search,
  # permission review) so no tool falls back to its native account.
  defaults = {
    model = "gpt-6.1-sol";
    helper = "gpt-6-luna";
  };
  remoteDefaults = lib.mapAttrs (_: id: "remote/${id}") defaults;
  remoteDir = "${config.xdg.configHome}/remote-agents";
  remoteRel = lib.removePrefix "${config.home.homeDirectory}/" remoteDir;

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
    # The remote/ models are listed here too: T3 runs one shared OpenCode
    # server without the project's direnv environment, so a T3 thread in a
    # Remote project (auto-review) has to name remote/<model> itself.
    # FIXME: that server's title and compaction agents still use the
    # personal helper model, so a compacted Remote thread sends its history
    # to a personal account. Needs T3 to start a second OpenCode instance
    # with OPENCODE_CONFIG set, or OpenCode to pick helpers per session.
    models = opencodeModels (personal ++ remote);
  };
  # Loaded on top of the user config through OPENCODE_CONFIG. Title and
  # compaction would otherwise pick a personal model of the same provider.
  opencodeRemote = {
    model = "cliproxy/${remoteDefaults.model}";
    agents = {
      title.model = "cliproxy/${remoteDefaults.helper}";
      compaction.model = "cliproxy/${remoteDefaults.helper}";
    };
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
  piSettings = model: ''
    if .defaultProvider == "cliproxy" and ((.defaultModel // "") | startswith("remote/")) == ${lib.boolToString (lib.hasPrefix "remote/" model)}
    then . else .defaultProvider = "cliproxy" | .defaultModel = "${model}" end
  '';

  # fx takes the permission reviewer from the provider, so Remote projects
  # select a second provider (FX_PROVIDER) rather than only a model.
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

  grokBackend = {
    messages = "messages";
    responses = "responses";
    chat = "chat_completions";
  };
  grok = models: {
    keys = ids models;
    model = byId models (m: {
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
  grokFilter = main: d: ''
    .model = ((.model // {}) + $proxy.model)
    | .models.allowed_models = $proxy.keys
    | .models |= (${grokPick "default" main}
        | ${grokPick "web_search" d.helper}
        | ${grokPick "session_summary" d.helper}
        | ${grokPick "image_description" d.helper}
        | ${grokPick "prompt_suggestion" d.helper})
    | .ui |= ((. // {}) | ${grokPick "fork_secondary_model" d.model})
  '';

  remoteEnv = {
    REMOTE_AGENTS = "1";
    ANTHROPIC_MODEL = "remote/claude-opus-5-5";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "remote/claude-opus-5-5";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "remote/claude-sonnet-5-5";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "remote/claude-haiku-5-5";
    ANTHROPIC_DEFAULT_FABLE_MODEL = "remote/claude-fable-5-1";
    CLAUDE_CODE_SUBAGENT_MODEL = "remote/claude-opus-5-5";
    OPENCODE_CONFIG = "${remoteDir}/opencode.json";
    PI_CODING_AGENT_DIR = "${remoteDir}/pi";
    GROK_HOME = "${remoteDir}/grok";
    FX_PROVIDER = "cliproxy-remote";
    FX_MODEL = remoteDefaults.model;
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    # Pi rewrites settings.json but only reads models.json.
    home.file.".pi/agent/models.json".text = builtins.toJSON (pi personal);

    xdg.configFile = {
      "remote-agents/pi/models.json".text = builtins.toJSON (pi remote);
      "remote-agents/opencode.json".text = builtins.toJSON opencodeRemote;
      "direnv/lib/remote-agents.sh".text = ''
        # Remote (work) projects: every agent tool uses remote/<model> only.
        use_remote_agents() {
        ${
          lib.concatStrings (lib.mapAttrsToList (n: v: "  export ${n}=${lib.escapeShellArg v}\n") remoteEnv)
        }}
      '';
    };

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
          | .model |= (if type == "string" and startswith("cliproxy/") then . else "cliproxy/${defaults.model}" end)
          | .policies = [
              {action: "provider.use", resource: "*", effect: "deny"},
              {action: "provider.use", resource: "cliproxy", effect: "allow"}
            ] + [(.policies // [])[] | select(.action != "provider.use" or (.resource | IN("*", "cliproxy") | not))]
        '';
      };

      piProxy = merge {
        path = ".pi/agent/settings.json";
        overlay = { };
        filter = piSettings defaults.model;
      };
      piRemoteProxy = merge {
        path = "${remoteRel}/pi/settings.json";
        overlay = { };
        filter = piSettings remoteDefaults.model;
      };

      fxProxy = merge {
        path = ".fx/settings.json";
        overlay = {
          cliproxy = fx personal defaults.helper;
          cliproxy-remote = fx remote remoteDefaults.helper;
        };
        filter = ''
          .providers = ((.providers // {}) + $proxy)
          | .provider = "cliproxy"
          | .models.cliproxy |= (if . == null then "${defaults.model}" else . end)
          | .models["cliproxy-remote"] |= (if . == null then "${remoteDefaults.model}" else . end)
        '';
      };

      grokProxy = merge {
        path = ".grok/config.toml";
        toml = true;
        overlay = grok personal;
        filter = grokFilter "grok-4.7" defaults;
      };
      grokRemoteProxy = merge {
        path = "${remoteRel}/grok/config.toml";
        toml = true;
        overlay = grok remote;
        filter = grokFilter remoteDefaults.model remoteDefaults;
      };
    };
  };
}
