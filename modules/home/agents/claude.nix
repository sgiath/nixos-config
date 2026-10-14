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

    # Claude rewrites settings.json itself (theme, plugins), so merge the
    # attribution policy into both config dirs instead of owning the file.
    # Without cleanupPeriodDays Claude deletes transcripts after 30 days.
    # The env block turns on OpenTelemetry (with the beta request/tool
    # tracing) to the local collector from archive.nix; Claude Code reads it
    # for every launch, including the ones T3 Code makes through the SDK.
    home.activation.claudeAttribution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for f in "$HOME/.claude/settings.json" "$HOME/.claude-remote/settings.json"; do
        old=$(cat "$f" 2>/dev/null || true)
        new=$(printf '%s' "''${old:-"{}"}" | ${lib.getExe pkgs.jq} --argjson env ${lib.escapeShellArg telemetryEnv} \
          '.attribution = {commit: "", pr: ""} | .cleanupPeriodDays = 36500 | .env = ((.env // {}) + $env)')
        if [ "$new" != "$old" ]; then
          run mkdir -p "$(dirname "$f")"
          run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
        fi
      done
    '';
  };
}
