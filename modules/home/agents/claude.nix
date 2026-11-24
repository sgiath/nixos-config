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

  # Exit 0 only when the path is a Nix store symlink or a readable directory
  # containing at least one Nix store symlink and nothing else, so a backup
  # holding any user-owned file is moved out of ~/.claude/skills/ instead of
  # deleted.
  isStoreOnlyBackupPy = ''
    import os, sys

    def is_store_link(p):
        if not os.path.islink(p):
            return False
        target = os.readlink(p)
        return target.startswith("/nix/store/") and os.path.normpath(target).startswith("/nix/store/")

    path = sys.argv[1]
    if os.path.islink(path):
        sys.exit(0 if is_store_link(path) else 1)
    if not os.path.isdir(path):
        sys.exit(1)

    def on_error(_err):
        sys.exit(1)

    found_store_link = False
    for root, dirs, files in os.walk(path, followlinks=False, onerror=on_error):
        if not dirs and not files:
            sys.exit(1)
        for name in dirs:
            entry = os.path.join(root, name)
            if os.path.islink(entry):
                if not is_store_link(entry):
                    sys.exit(1)
                found_store_link = True
        for name in files:
            entry = os.path.join(root, name)
            if not is_store_link(entry):
                sys.exit(1)
            found_store_link = True
    sys.exit(0 if found_store_link else 1)
  '';

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

    # Remove or evacuate Home Manager backups of the generated MCP plugin
    # (Claude Code auto-loads every ~/.claude/skills/* directory with a plugin
    # manifest, so a .backup resurrects removed MCP servers) and uninstall the
    # previously Nix-installed user-scope whiteboard@devfast plugin (keeping
    # any saved plugin data) and its user-scope devfast marketplace when no
    # other @devfast plugin remains. Runs after linkGeneration (which creates
    # .backup files) and before claudeAttribution (which normalizes
    # settings.json after Claude edits it).
    home.activation.claudePluginCleanup =
      lib.hm.dag.entryBetween [ "claudeAttribution" ] [ "linkGeneration" ]
        ''
          backup="$HOME/.claude/skills/claude-code-home-manager.backup"
          if [[ -e $backup || -L $backup ]]; then
            if ${lib.escapeShellArg (lib.getExe pkgs.python3)} -I -c ${lib.escapeShellArg isStoreOnlyBackupPy} "$backup" 2>/dev/null; then
              run rm -rf $VERBOSE_ARG "$backup"
            else
              backups_dir="$HOME/.claude/backups"
              dest="$backups_dir/claude-code-home-manager.backup"
              if [[ -e $dest || -L $dest ]]; then
                ts=$(${lib.escapeShellArg (lib.getExe' pkgs.coreutils "date")} +%Y%m%d%H%M%S)
                dest="$backups_dir/claude-code-home-manager.backup.$ts"
                i=1
                while [[ -e $dest || -L $dest ]]; do
                  dest="$backups_dir/claude-code-home-manager.backup.$ts.$i"
                  i=$((i + 1))
                done
              fi
              run mkdir -p "$backups_dir"
              run mv $VERBOSE_ARG "$backup" "$dest"
              if [[ ! -v DRY_RUN ]]; then
                echo "Claude: moved non-store $backup to $dest so Claude Code does not load it as a plugin" >&2
              fi
            fi
          fi

          installed="$HOME/.claude/plugins/installed_plugins.json"
          marketplaces="$HOME/.claude/plugins/known_marketplaces.json"
          settings="$HOME/.claude/settings.json"
          claude_exe=${lib.escapeShellArg (lib.getExe config.programs.claude-code.package)}
          env_exe=${lib.escapeShellArg (lib.getExe' pkgs.coreutils "env")}
          jq_exe=${lib.escapeShellArg (lib.getExe pkgs.jq)}
          timeout_exe=${lib.escapeShellArg (lib.getExe' pkgs.coreutils "timeout")}

          if [[ -f $installed ]] && "$jq_exe" -e '(.plugins? | type == "object") and ((.plugins["whiteboard@devfast"] // []) | type == "array" and any(type == "object" and .scope == "user"))' "$installed" >/dev/null 2>&1; then
            if [[ -v DRY_RUN ]]; then
              echo "Would uninstall Claude plugin whiteboard@devfast"
            else
              if out=$("$env_exe" -u CLAUDE_CONFIG_DIR "$timeout_exe" 60 "$claude_exe" plugin uninstall whiteboard@devfast --scope user --keep-data </dev/null 2>&1); then
                echo "Claude: uninstalled plugin whiteboard@devfast"
              else
                echo "Claude: uninstalling plugin whiteboard@devfast failed; activation continues:" >&2
                echo "$out" >&2
              fi
            fi
          fi

          if [[ -f $settings && -f $marketplaces ]] \
            && "$jq_exe" -e 'type == "object" and (.extraKnownMarketplaces? | type == "object") and (.extraKnownMarketplaces.devfast? | type == "object") and (.extraKnownMarketplaces.devfast.source? | type == "object") and .extraKnownMarketplaces.devfast.source.repo? == "devdotfast/whiteboard"' "$settings" >/dev/null 2>&1 \
            && "$jq_exe" -e 'type == "object" and (.devfast? | type == "object") and (.devfast.source? | type == "object") and .devfast.source.repo? == "devdotfast/whiteboard"' "$marketplaces" >/dev/null 2>&1 \
            && ( [[ ! -f $installed ]] || "$jq_exe" -e 'type == "object" and ((.plugins // {}) | type == "object" and (keys | all(endswith("@devfast") | not)))' "$installed" >/dev/null 2>&1 ); then
            if [[ -v DRY_RUN ]]; then
              echo "Would remove Claude plugin marketplace devfast (user scope)"
            else
              if out=$("$env_exe" -u CLAUDE_CONFIG_DIR "$timeout_exe" 60 "$claude_exe" plugin marketplace remove --scope user devfast </dev/null 2>&1); then
                echo "Claude: removed plugin marketplace devfast (user scope)"
              else
                echo "Claude: removing plugin marketplace devfast failed; activation continues:" >&2
                echo "$out" >&2
              fi
            fi
          fi
        '';

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
