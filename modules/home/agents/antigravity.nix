{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.antigravity-cli;

  # Match Home Manager's native immutable mcp_config.json gate so referencing
  # home.file.".gemini/config/mcp_config.json".source never fails if a host
  # switches to mutableSettings, legacy Gemini config, or empties mcpServers.
  useGeminiConfig =
    cfg.useLegacyGeminiConfig || (cfg.package != null && lib.getName cfg.package == "gemini-cli");
  hasImmutableMcpConfig =
    cfg.enable
    && !cfg.mutableSettings
    && !useGeminiConfig
    && (cfg.mcpServers != { } || (cfg.settings.mcpServers or { }) != { });

  # T3 Code launches `agy acp` against an isolated GEMINI_HOME under
  # ~/.t3/userdata/providers/antigravity/<sha256(instanceId)> and symlinks
  # rules and skills from ~/.gemini, but omits config/mcp_config.json
  # (`t3code-antigravity-mcp-config` in UPSTREAM-WORKAROUNDS.md).
  t3ProfileDir = ".t3/userdata/providers/antigravity/${builtins.hashString "sha256" "antigravity"}";
  t3McpConfig = "${t3ProfileDir}/config/mcp_config.json";
in
{
  config = lib.mkIf config.sgiath.agents.enable (
    lib.mkMerge [
      {
        # `agy`; T3 Code picks it up from PATH as its Antigravity provider.
        programs.antigravity-cli = {
          enable = true;
          package = pkgs.llm-agents.antigravity-cli;
          # ~/.gemini/AGENTS.md and ~/.gemini/antigravity-cli/skills; T3 Code
          # symlinks both into its own Antigravity profile (GEMINI_HOME).
          context.AGENTS = ./AGENTS.md;
          skills = ./skills;
          mcpServers = {
            # Antigravity CLI 1.5.13 does not run MCP OAuth on Streamable HTTP
            # (executor returns 401 Unauthorized on initialize), so bridge it
            # through Nix-pinned mcp-remote; switch to serverUrl once agy handles
            # MCP OAuth natively.
            executor = {
              command = lib.getExe pkgs.llm-agents.mcp-remote;
              args = [
                config.programs.mcp.servers.executor.url
              ];
            };
          };
        };
      }

      (lib.mkIf (config.services.t3code.enable && hasImmutableMcpConfig) {
        home.file.${t3McpConfig}.source = config.home.file.".gemini/config/mcp_config.json".source;

        # Runs after writeBoundary so failed pre-checks never mutate disk:
        # keep T3's private directories 0700 on fresh hosts (linkGeneration
        # would otherwise mkdir -p with default umask), and drop the empty
        # placeholder `agy` creates on first start so linkGeneration links
        # directly without leaving a 0-byte .backup file behind.
        home.activation.t3codeAntigravityMcp =
          lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
            ''
              if [[ ! -e "$HOME/.t3" ]]; then
                run mkdir -p "$HOME/.t3"
              fi
              for dir in \
                "$HOME/.t3/userdata" \
                "$HOME/.t3/userdata/providers" \
                "$HOME/.t3/userdata/providers/antigravity" \
                "$HOME/${t3ProfileDir}" \
                "$HOME/${t3ProfileDir}/config"
              do
                if [[ ! -e $dir ]]; then
                  run mkdir -m 700 "$dir"
                fi
              done
              target="$HOME/${t3McpConfig}"
              if [[ -f $target && ! -L $target ]] && {
                [[ ! -s $target ]] || ${lib.getExe pkgs.jq} -e 'type == "object" and ((.mcpServers // {}) | type == "object" and length == 0) and (del(.mcpServers) | length == 0)' "$target" >/dev/null 2>&1
              }; then
                run rm $VERBOSE_ARG -- "$target"
              fi
            '';
      })
    ]
  );
}
