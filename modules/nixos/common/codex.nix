{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Codex's system config layer, below ~/.codex{,-remote}/config.toml which
  # Codex itself rewrites. The local collector on :4318 is the HM otel-agent
  # service (modules/home/agents/archive.nix). ~/.codex-remote sets its own
  # model_provider, so the cliproxy default applies to ~/.codex only.
  agents = config.home-manager.users.sgiath.sgiath.agents;
in
{
  config = lib.mkIf (config.sgiath.enable && agents.enable) {
    environment.etc."codex/config.toml".source = (pkgs.formats.toml { }).generate "codex-config.toml" {
      # Inference through CLIProxyAPI; `codex --profile remote` switches to
      # the Remote model (~/.codex/remote.config.toml, modules/home/agents/codex.nix).
      # FIXME: websockets stay off until Responses websocket continuation
      # through the proxy is tested.
      model_provider = "cliproxy";
      model_providers.cliproxy = {
        name = "CLIProxyAPI";
        base_url = "${agents.cliproxyUrl}/v1";
        env_key = "CLIPROXY_API_KEY";
        wire_api = "responses";
        requires_openai_auth = false;
        supports_websockets = false;
      };
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
