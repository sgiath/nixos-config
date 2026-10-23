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

  # T3 cannot read GitLab merge requests: every GitLab watch fails, yet long-lived
  # coordinator threads kept briefing workers to use it (117 calls, 2026-10-16..23).
  # FIXME: Codex has no equivalent guard; add one if Codex threads start watching GitLab MRs.
  gitlabWatchGuard = pkgs.writeShellApplication {
    name = "claude-gitlab-watch-guard";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if jq -e '[.tool_input | .. | strings]
        | any(test("^(https?://)?([^/]+\\.)?gitlab\\.[^/]+(/|$)|/-/merge_requests/"; "i"))' >/dev/null; then
        jq -n '{hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: "T3 cannot read GitLab merge requests, so this watch would only fail. Wait for the pipeline with the repository'"'"'s babysit-mr skill instead."
        }}'
      fi
    '';
  };
  gitlabWatchHook = builtins.toJSON {
    matcher = "mcp__t3-code__watch_pull_request";
    hooks = [
      {
        type = "command";
        command = lib.getExe gitlabWatchGuard;
      }
    ];
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
    # The GitLab watch guard replaces only its own command (any store path),
    # keeping other hooks, including ones on the same matcher.
    home.activation.claudeAttribution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for f in "$HOME/.claude/settings.json" "$HOME/.claude-remote/settings.json"; do
        old=$(cat "$f" 2>/dev/null || true)
        new=$(printf '%s' "''${old:-"{}"}" | ${lib.getExe pkgs.jq} --argjson env ${lib.escapeShellArg telemetryEnv} \
          --argjson guard ${lib.escapeShellArg gitlabWatchHook} \
          '.attribution = {commit: "", pr: ""} | .cleanupPeriodDays = 36500 | .env = ((.env // {}) + $env)
           | .hooks.PreToolUse = ([.hooks.PreToolUse[]?
               | .hooks |= map(select((.command // "") | endswith("/bin/claude-gitlab-watch-guard") | not))
               | select(.hooks | length > 0)] + [$guard])')
        if [ "$new" != "$old" ]; then
          run mkdir -p "$(dirname "$f")"
          run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
        fi
      done
    '';
  };
}
