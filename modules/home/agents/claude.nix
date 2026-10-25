{
  config,
  lib,
  pkgs,
  ...
}:
let
  telemetryEnv = builtins.toJSON {
    CLAUDE_CODE_ENABLE_TELEMETRY = "1";
    CLAUDE_CODE_ENHANCED_TELEMETRY_BETA = "1";
    OTEL_METRICS_EXPORTER = "otlp";
    OTEL_LOGS_EXPORTER = "otlp";
    OTEL_TRACES_EXPORTER = "otlp";
    OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://127.0.0.1:4318";
    OTEL_METRICS_INCLUDE_SESSION_ID = "true";
    OTEL_LOG_USER_PROMPTS = "1";
    OTEL_LOG_TOOL_DETAILS = "1";
  };

in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home = {
      packages = with pkgs.llm-agents; [ claude-desktop ];
      file.".claude-remote/CLAUDE.md".source = ./AGENTS.md;
      file.".claude-remote/skills" = {
        source = ./skills;
        recursive = true;
      };
    };

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
          "$HOME/.claude" "$HOME/.claude-remote"
      ''
    );

    # Claude rewrites settings.json itself (theme, plugins), so merge the
    # attribution policy into both config dirs instead of owning the file.
    # Without cleanupPeriodDays Claude deletes transcripts after 30 days.
    # The env block turns on OpenTelemetry (with the beta request/tool
    # tracing) to the local collector from archive.nix; Claude Code reads it
    # for every launch, including the ones T3 Code makes through the SDK.
    # Earlier generations installed a PreToolUse guard that blocked T3 GitLab
    # MR watches; T3 supports GitLab now, so drop only that command (any store
    # path), keeping other hooks on the same matcher and leaving settings
    # without it untouched.
    # FIXME: delete the migration once every agents host has activated it.
    home.activation.claudeAttribution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for f in "$HOME/.claude/settings.json" "$HOME/.claude-remote/settings.json"; do
        old=$(cat "$f" 2>/dev/null || true)
        new=$(printf '%s' "''${old:-"{}"}" | ${lib.getExe pkgs.jq} --argjson env ${lib.escapeShellArg telemetryEnv} \
          'def guard: (.command? // "") | tostring | endswith("/bin/claude-gitlab-watch-guard");
           .attribution = {commit: "", pr: ""} | .cleanupPeriodDays = 36500 | .env = ((.env // {}) + $env)
           | if any(.hooks.PreToolUse[]?.hooks[]?; guard) then
               .hooks.PreToolUse |= map(.hooks |= map(select(guard | not)) | select(.hooks | length > 0))
               | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end
               | if .hooks == {} then del(.hooks) else . end
             else . end')
        if [ "$new" != "$old" ]; then
          run mkdir -p "$(dirname "$f")"
          run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
        fi
      done
    '';
  };
}
