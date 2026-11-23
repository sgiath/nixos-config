{
  config,
  lib,
  pkgs,
  apiKeyWrapper,
  ...
}:
let
  # Enhanced telemetry gives the request and tool spans otel.sql reads.
  # Metrics and prompt/tool content stay off: nothing reads them and
  # archive.raw has the content (agent-archive/otel-policy.nix). The
  # activation below merges into settings.json, so turning a key off means
  # setting it, not omitting it.
  telemetryEnv = builtins.toJSON {
    CLAUDE_CODE_ENABLE_TELEMETRY = "1";
    CLAUDE_CODE_ENHANCED_TELEMETRY_BETA = "1";
    OTEL_METRICS_EXPORTER = "none";
    OTEL_LOGS_EXPORTER = "otlp";
    OTEL_TRACES_EXPORTER = "otlp";
    OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:4318";
    OTEL_LOG_USER_PROMPTS = "0";
    OTEL_LOG_TOOL_DETAILS = "0";
    CLAUDE_CODE_EVEN_MORE_DANGEROUSLY_SKIP_PERMISSIONS = "1";
  };

  # Inference through CLIProxyAPI so the two Claude subscriptions rotate and
  # Mythos routes to the personal login. The helper wins over the saved
  # claude.ai login, which stays in place for rollback.
  proxySettings = builtins.toJSON {
    env.ANTHROPIC_BASE_URL = config.sgiath.agents.cliproxyUrl;
    apiKeyHelper = "${lib.getExe apiKeyWrapper} ${pkgs.coreutils}/bin/printenv CLIPROXY_API_KEY";
  };

  # T3 Code's bundled claudeAgent catalog omits Mythos, and Claude Code's
  # supportedModels() does not advertise it under a custom ANTHROPIC_BASE_URL.
  # Registering it in customModels with its effort descriptor exposes it on
  # claudeAgent directly; CLIProxyAPI routes it to the personal Claude login.
  mythosT3Model = {
    slug = "claude-mythos-5-2";
    name = "Claude Mythos 5.2";
    capabilities.optionDescriptors = [
      {
        id = "effort";
        label = "Reasoning";
        type = "select";
        options = [
          {
            id = "low";
            label = "Low";
          }
          {
            id = "medium";
            label = "Medium";
            isDefault = true;
          }
          {
            id = "high";
            label = "High";
          }
          {
            id = "xhigh";
            label = "Extra High";
          }
          {
            id = "max";
            label = "Max";
          }
        ];
      }
    ];
  };

in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = with pkgs.llm-agents; [ claude-desktop ];

    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;
      package = pkgs.llm-agents.claude-code;
      context = ./AGENTS.md;
      skills = ./skills;
    };

    # Whiteboard ships only an amd64 build (base.nix), so other hosts skip the
    # plugin. This runs before claudeAttribution, which then normalizes the
    # settings.json Claude rewrote, keeping later activations byte-identical.
    home.activation.claudeWhiteboard = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
      lib.hm.dag.entryBetween [ "claudeAttribution" ] [ "writeBoundary" ] ''
        run ${lib.getExe (pkgs.callPackage ./whiteboard-plugin.nix { })} claude \
          ${lib.getExe config.programs.claude-code.package} \
          ${lib.escapeShellArg "${config.home.profileDirectory}/bin/whiteboard"} \
          "$HOME/.claude"
      ''
    );

    # Claude rewrites settings.json itself (theme, plugins), so merge the
    # attribution policy into it instead of owning the file.
    # Without cleanupPeriodDays Claude deletes transcripts after 30 days.
    # The env block turns on OpenTelemetry (with the beta request/tool
    # tracing) to the local collector from archive.nix; Claude Code reads it
    # for every launch, including the ones T3 Code makes through the SDK.
    home.activation.claudeAttribution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.claude/settings.json"
      old=$(cat "$f" 2>/dev/null || true)
      new=$(printf '%s' "''${old:-"{}"}" | ${lib.getExe pkgs.jq} --argjson env ${lib.escapeShellArg telemetryEnv} \
        '.attribution = {commit: "", pr: ""} | .cleanupPeriodDays = 36500 | .env = ((.env // {}) + $env)')
      if [ "$new" != "$old" ]; then
        run mkdir -p "$(dirname "$f")"
        run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
      fi
    '';

    home.activation.claudeProxy = lib.hm.dag.entryAfter [ "claudeAttribution" ] ''
      f="$HOME/.claude/settings.json"
      old=$(cat "$f" 2>/dev/null || true)
      new=$(printf '%s' "''${old:-"{}"}" | ${lib.getExe pkgs.jq} --argjson proxy ${lib.escapeShellArg proxySettings} \
        '.apiKeyHelper = $proxy.apiKeyHelper | .env = ((.env // {}) + $proxy.env)')
      if [ "$new" != "$old" ]; then
        run mkdir -p "$(dirname "$f")"
        run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
      fi
    '';

    # settings.json is app-owned (T3 reloads it on change): add Mythos when
    # absent, and ensure a bare string or partial Mythos entry has an effort
    # descriptor while preserving any custom name and sibling descriptors.
    home.activation.t3codeClaudeMythos = lib.mkIf config.services.t3code.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="$HOME/.t3/userdata/settings.json"
        current='{}'
        [[ -f $settings ]] && current=$(cat "$settings")
        if ${lib.getExe pkgs.jq} -e 'type == "object"' <<<"$current" >/dev/null 2>&1; then
          if ! ${lib.getExe pkgs.jq} -e '(.providerInstances.claudeAgent.config.customModels // []) | any(type == "object" and .slug == "claude-mythos-5-2" and ((.capabilities.optionDescriptors? | type) == "array") and (.capabilities.optionDescriptors | any(type == "object" and .id == "effort")))' <<<"$current" >/dev/null; then
            updated=$(${lib.getExe pkgs.jq} --argjson model ${lib.escapeShellArg (builtins.toJSON mythosT3Model)} '
              .providerInstances //= {}
              | .providerInstances.claudeAgent //= {driver: "claudeAgent", enabled: true, config: {}}
              | .providerInstances.claudeAgent.config //= {}
              | .providerInstances.claudeAgent.config.customModels = (
                  (.providerInstances.claudeAgent.config.customModels // []) as $list
                  | if ($list | any((if type == "string" then . else .slug? end) == "claude-mythos-5-2")) then
                      $list | map(
                        if . == "claude-mythos-5-2" then $model
                        elif (type == "object" and .slug == "claude-mythos-5-2") then
                          ($model + . + {
                            name: (.name // $model.name),
                            capabilities: ((.capabilities // {}) + {
                              optionDescriptors: ($model.capabilities.optionDescriptors + ((.capabilities.optionDescriptors? | if type == "array" then . else [] end) | map(select((type == "object" and .id == "effort") | not))))
                            })
                          })
                        else . end
                      )
                    else
                      $list + [$model]
                    end
                )
            ' <<<"$current")
            if [[ -v DRY_RUN ]]; then
              echo "Would register claude-mythos-5-2 in claudeAgent.config.customModels in $settings"
            else
              # Replaced by rename so T3's watcher never reads a partial file;
              # mktemp keeps the file private like T3's own writes.
              mkdir -p "$(dirname "$settings")"
              tmp=$(mktemp "$settings.XXXXXX")
              printf '%s\n' "$updated" >"$tmp"
              mv "$tmp" "$settings"
            fi
          fi
        else
          echo "claude: cannot parse $settings; leaving claudeAgent customModels unchanged" >&2
        fi
      ''
    );
  };
}
