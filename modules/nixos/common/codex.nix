{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Codex's system config layer, below ~/.codex{,-remote}/config.toml which
  # Codex itself rewrites. The local collector on :4318 is the HM otel-agent
  # service (modules/home/agents/archive.nix).
  exporter = signal: {
    otlp-http = {
      endpoint = "http://127.0.0.1:4318/v1/${signal}";
      protocol = "binary";
    };
  };
in
{
  config = lib.mkIf (config.sgiath.enable && config.home-manager.users.sgiath.sgiath.agents.enable) {
    environment.etc."codex/config.toml".source = (pkgs.formats.toml { }).generate "codex-config.toml" {
      otel = {
        environment = config.networking.hostName;
        log_user_prompt = true;
        exporter = exporter "logs";
        trace_exporter = exporter "traces";
        metrics_exporter = exporter "metrics";
      };
    };
  };
}
