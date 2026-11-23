{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Codex's system config layer, below ~/.codex/config.toml which Codex
  # itself rewrites. Codex uses its native OpenAI login in ~/.codex/auth.json.
  # The local collector on :4318 is the HM otel-agent service
  # (modules/home/agents/archive.nix).
  agents = config.home-manager.users.sgiath.sgiath.agents;
in
{
  config = lib.mkIf (config.sgiath.enable && agents.enable) {
    environment.etc."codex/config.toml".source = (pkgs.formats.toml { }).generate "codex-config.toml" {
      # Only logs: otel.sql reads completions and tool results. An omitted
      # metrics_exporter means Statsig, not none. Prompt text and SSE deltas
      # stay off (modules/nixos/services/agent-archive/otel-policy.nix).
      otel = {
        environment = config.networking.hostName;
        exporter.otlp-http = {
          endpoint = "http://127.0.0.1:4318/v1/logs";
          protocol = "binary";
        };
        trace_exporter = "none";
        metrics_exporter = "none";
        log_sse_deltas = false;
      };
    };
  };
}
