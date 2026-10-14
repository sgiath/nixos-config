{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  otelcol = lib.getExe' pkgs.opentelemetry-collector-contrib "otelcol-contrib";

  # Claude Code and Codex send OpenTelemetry here (claude.nix and
  # modules/nixos/common/codex.nix). Exporting straight to Vesta stalls `codex exec` for
  # 13-20 s at exit whenever Vesta is unreachable; this collector answers
  # locally and forwards from a disk queue, so telemetry produced away from
  # home arrives later instead of being dropped.
  otelAgentConfig =
    let
      yaml = (pkgs.formats.yaml { }).generate "otel-agent.yaml" {
        extensions.file_storage = {
          directory = "${config.xdg.stateHome}/otel-agent";
          create_directory = true;
        };
        receivers.otlp.protocols.http.endpoint = "127.0.0.1:4318";
        processors = {
          # Neither tool names the machine in its telemetry.
          resource.attributes = [
            {
              key = "host.name";
              value = osConfig.networking.hostName;
              action = "upsert";
            }
          ];
          batch = { };
        };
        exporters.otlp_http = {
          endpoint = "https://otel.sgiath.dev";
          sending_queue.storage = "file_storage";
          retry_on_failure.max_elapsed_time = "0s";
        };
        service = {
          telemetry.metrics.level = "none";
          extensions = [ "file_storage" ];
          pipelines = lib.genAttrs [ "logs" "traces" "metrics" ] (_: {
            receivers = [ "otlp" ];
            processors = [
              "resource"
              "batch"
            ];
            exporters = [ "otlp_http" ];
          });
        };
      };
    in
    pkgs.runCommandLocal "otel-agent.yaml" { } ''
      ${otelcol} validate --config=file:${yaml}
      cp ${yaml} $out
    '';

  # `agent-archive-ship`; its tests run as part of the build.
  shipper = pkgs.runCommandLocal "agent-archive-ship" { } ''
    PYTHONDONTWRITEBYTECODE=1 ${lib.getExe pkgs.python3} -I -m unittest discover \
      -s ${./archive} -t ${./archive}
    install -Dm755 ${./archive/ship.py} $out/bin/agent-archive-ship
    sed -i '1c#!${lib.getExe pkgs.python3} -I' $out/bin/agent-archive-ship
  '';
in
{
  # Hourly copy of this host's agent sessions into services.agent-archive on
  # Vesta (sources and cursors are described in archive/ship.py), and the
  # local OpenTelemetry collector the agents report to.
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ shipper ];

    systemd.user.services.agent-archive = {
      Unit.Description = "Ship agent sessions to the archive";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe' shipper "agent-archive-ship";
        Nice = 10;
        IOSchedulingClass = "idle";
        # The first run on a host backfills its whole history.
        TimeoutStartSec = "3h";
      };
    };

    # Daily check for session stores the shipper does not know about (a new
    # harness, a new profile); fails and posts to ntfy topic agent-archive.
    systemd.user.services.agent-archive-discover = {
      Unit.Description = "Look for agent sessions the archive misses";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe' shipper "agent-archive-ship"} --discover";
        Nice = 10;
        IOSchedulingClass = "idle";
        TimeoutStartSec = "30min";
      };
    };
    systemd.user.timers.agent-archive-discover = {
      Unit.Description = "Look for agent sessions the archive misses daily";
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.otel-agent = {
      Unit.Description = "Forward agent telemetry to the archive";
      Service = {
        ExecStart = "${otelcol} --config=file:${otelAgentConfig}";
        Restart = "always";
        RestartSec = 5;
        # Stopping retries the in-flight send until the timeout; with Vesta
        # unreachable that holds the queue lock. Unsent data stays on disk.
        TimeoutStopSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.agent-archive = {
      Unit.Description = "Ship agent sessions to the archive hourly";
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
