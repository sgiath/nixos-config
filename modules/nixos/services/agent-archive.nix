{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.agent-archive;
  nebula = config.sgiath.nebula;
  ch = config.services.clickhouse.package;
  host = "clickhouse.sgiath.dev";
  # 8123/9000 are taken on Vesta (Home Assistant, MinIO).
  httpPort = 8124;
  tcpPort = 9001;
  backupDir = "/var/backup/agent-archive";
  # OTLP/HTTP forwarded by each host's local collector
  # (modules/home/agents/archive.nix, which owns :4318 on every host),
  # written by this collector into the `otel` database.
  otelHost = "otel.sgiath.dev";
  otlpPort = 4319;
  client = "${ch}/bin/clickhouse-client --port ${toString tcpPort} --user archive";
  # Per-tool parsing views, then the tables they fill.
  derivedSql = [
    ./agent-archive/otel.sql
    ./agent-archive/claude.sql
    ./agent-archive/codex.sql
    ./agent-archive/pi.sql
    ./agent-archive/opencode.sql
    ./agent-archive/opencode_hooks.sql
    ./agent-archive/tables.sql
  ];
in
{
  # Every agent session from every host (modules/home/agents/archive.nix ships
  # them hourly) in ClickHouse on /data, with a daily Parquet copy of the raw
  # records on the root disk. Nebula is the auth: the `default` user is
  # read-only for analysis, `archive` writes.
  options.services.agent-archive = {
    enable = lib.mkEnableOption "agent session archive (ClickHouse)";
  };

  config = lib.mkMerge [
    {
      sgiath.nebula.services = [
        "clickhouse"
        "otel"
      ];
    }

    (lib.mkIf (config.sgiath.roles.server.enable && cfg.enable) {
      services.clickhouse = {
        enable = true;

        serverConfig = {
          http_port = httpPort;
          tcp_port = tcpPort;
          mysql_port."@remove" = 1;
          postgresql_port."@remove" = 1;
          interserver_http_port."@remove" = 1;

          max_server_memory_usage = 8 * 1024 * 1024 * 1024;
          mark_cache_size = 1024 * 1024 * 1024;

          # The default system logs grow without bound; keep the two worth
          # reading, with a TTL.
          query_log.ttl = "event_date + INTERVAL 30 DAY DELETE";
          backup_log.ttl = "event_date + INTERVAL 30 DAY DELETE";
        }
        //
          lib.genAttrs
            [
              "trace_log"
              "query_thread_log"
              "query_views_log"
              "part_log"
              "background_schedule_pool_log"
              "text_log"
              "metric_log"
              "error_log"
              "query_metric_log"
              "asynchronous_metric_log"
              "processors_profile_log"
              "asynchronous_insert_log"
              "blob_storage_log"
            ]
            (_: {
              "@remove" = 1;
            });

        usersConfig = {
          profiles.readonly.readonly = 2;
          users = {
            default.profile = "readonly";
            archive = {
              password = "";
              profile = "default";
              quota = "default";
              networks.ip = [
                "::1"
                "127.0.0.1"
              ];
            };
          };
        };
      };

      # Telemetry is kept forever like the session records (no TTL). The
      # queue is on disk and retried without limit, so a ClickHouse restart
      # loses nothing that reached the collector.
      services.opentelemetry-collector = {
        enable = true;
        package = pkgs.opentelemetry-collector-contrib;
        settings = {
          extensions.file_storage = {
            directory = "/var/lib/opentelemetry-collector";
            create_directory = true;
          };
          receivers.otlp.protocols.http.endpoint = "127.0.0.1:${toString otlpPort}";
          processors.batch = { };
          exporters.clickhouse = {
            endpoint = "tcp://127.0.0.1:${toString tcpPort}";
            username = "archive";
            database = "otel";
            create_schema = true;
            sending_queue.storage = "file_storage";
            retry_on_failure.max_elapsed_time = "0s";
          };
          service = {
            # No self-metrics listener (it would claim :8888).
            telemetry.metrics.level = "none";
            extensions = [ "file_storage" ];
            pipelines = lib.genAttrs [ "logs" "traces" "metrics" ] (_: {
              receivers = [ "otlp" ];
              processors = [ "batch" ];
              exporters = [ "clickhouse" ];
            });
          };
        };
      };
      systemd.services.opentelemetry-collector = {
        wants = [ "clickhouse.service" ];
        after = [ "clickhouse.service" ];
      };

      systemd.tmpfiles.rules = [
        "d /data/clickhouse 0750 clickhouse clickhouse -"
        "d ${backupDir} 0750 root root -"
      ];
      systemd.services.clickhouse.serviceConfig.BindPaths = [ "/data/clickhouse:/var/lib/clickhouse" ];

      # archive.raw is created once and never dropped. The `agents` database
      # holds only what is derived from it, so it is rebuilt whole whenever
      # the SQL changes and refreshed right away.
      systemd.services.agent-archive-schema = {
        description = "Agent archive schema";
        wantedBy = [ "multi-user.target" ];
        requires = [ "clickhouse.service" ];
        wants = [ "opentelemetry-collector.service" ];
        after = [
          "clickhouse.service"
          "opentelemetry-collector.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "10min";
        };
        # The derived views read the collector's tables, which its exporter
        # creates when it starts.
        script = ''
          for _ in $(seq 60); do
            [ "$(${client} --query "SELECT count() FROM system.tables
              WHERE database = 'otel' AND name IN ('otel_traces', 'otel_logs')")" = 2 ] && break
            sleep 2
          done
          ${client} --queries-file ${./agent-archive/raw.sql}
          ${client} --multiquery --query 'DROP DATABASE IF EXISTS agents SYNC; CREATE DATABASE agents'
          ${lib.concatMapStrings (sql: "${client} --queries-file ${sql}\n") derivedSql}
          ${client} --multiquery --query '
            SYSTEM REFRESH VIEW agents.requests_refresh;
            SYSTEM REFRESH VIEW agents.tool_calls_refresh;
            SYSTEM WAIT VIEW agents.tool_calls_refresh;
            SYSTEM REFRESH VIEW agents.commands_refresh'
        '';
      };

      # One Parquet file per ingest month of archive.raw, rewritten only when
      # that partition changed. The files are self-contained (readable by
      # ClickHouse, DuckDB, pandas); restore with
      #   clickhouse-client --port 9001 --user archive \
      #     --query 'INSERT INTO archive.raw FORMAT Parquet' < raw-YYYYMM.parquet
      # FIXME: the copy is on Vesta's root disk, the same machine as the
      # database. Add an offsite sync of ${backupDir} (restic, rclone) once a
      # destination is chosen.
      systemd.services.agent-archive-backup = {
        description = "Agent archive Parquet backup";
        requires = [ "clickhouse.service" ];
        after = [
          "clickhouse.service"
          "agent-archive-schema.service"
        ];
        serviceConfig.Type = "oneshot";
        path = [ pkgs.coreutils ];
        script = ''
          set -euo pipefail
          cd ${backupDir}
          ${client} --format TSV --query "
            SELECT _partition_id, count(), max(ingested_at)
            FROM archive.raw GROUP BY _partition_id ORDER BY _partition_id
          " | while IFS=$'\t' read -r part rows newest; do
            stamp="$rows $newest"
            if [ "$(cat "raw-$part.stamp" 2>/dev/null)" = "$stamp" ]; then
              continue
            fi
            ${client} --query "
              SELECT * FROM archive.raw WHERE _partition_id = '$part'
              ORDER BY tool, host, source, key FORMAT Parquet
            " > "raw-$part.parquet.tmp"
            mv "raw-$part.parquet.tmp" "raw-$part.parquet"
            echo "$stamp" > "raw-$part.stamp"
            echo "raw-$part.parquet: $rows rows"
          done
        '';
      };
      systemd.timers.agent-archive-backup = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };

      services.nginx.virtualHosts.${host} = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # Overlay only
        extraConfig = ''
          allow ${nebula.cidr4};
          allow ${nebula.cidr6};
          deny all;
        '';

        # Shippers stream large INSERT bodies; analysis queries can run long.
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString httpPort}";
          extraConfig = ''
            client_max_body_size 0;
            proxy_request_buffering off;
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
          '';
        };
      };

      services.nginx.virtualHosts.${otelHost} = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # Overlay only
        extraConfig = ''
          allow ${nebula.cidr4};
          allow ${nebula.cidr6};
          deny all;
        '';

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString otlpPort}";
          extraConfig = "client_max_body_size 64m;";
        };
      };
    })
  ];
}
