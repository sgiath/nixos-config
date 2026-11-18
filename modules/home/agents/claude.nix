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

  # Inference through CLIProxyAPI with the shared proxy key. The helper wins
  # over the saved claude.ai login, which stays in place for rollback.
  proxySettings = builtins.toJSON {
    env.ANTHROPIC_BASE_URL = config.sgiath.agents.cliproxyUrl;
    apiKeyHelper = "${lib.getExe apiKeyWrapper} ${pkgs.coreutils}/bin/printenv CLIPROXY_API_KEY";
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
  };
}
