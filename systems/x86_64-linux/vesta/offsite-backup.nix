# Nightly encrypted restic backup of Vesta's irreplaceable state to the
# append-only REST server on Hygiea (systems/aarch64-linux/hygiea/backup.nix).
# Vesta can add snapshots but not delete them; Ceres prunes
# (systems/x86_64-linux/ceres/offsite-prune.nix). Hygiea never sees the
# repository password, which also lives in secrets/ceres.yaml for restores.
#
# Not backed up: anything rebuildable or downloaded (Nix store, Docker and
# container storage, media, chain data, OSM tiles, caches, dependencies),
# Docker dev databases, OTel telemetry and the live ClickHouse store (the agent
# archive is covered by its Parquet copies in /var/backup/agent-archive).
#
# Databases are copied consistently before the run into /var/backup/offsite,
# and the live files are excluded: every SQLite database under the backed-up
# paths through SQLite's online backup, and Continuwuity's RocksDB by stopping
# Matrix for the copy. Restore by copying them back over the live paths.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  hygiea = config.sgiath.nebula.peers.hygiea;
  staging = "/var/backup/offsite";
  matrixState = "/var/lib/private/continuwuity";
  paths = [
    "/data"
    "/data3/lightning"
    "/data3/lnbits"
    "/etc/ssh"
    "/home/sgiath"
    "/root"
    "/var/backup/agent-archive"
    "/var/lib"
    staging
  ];
  # Directories never worth descending into, for restic and the SQLite search.
  skipNames = [
    "node_modules"
    ".cache"
    ".next"
    "_build"
    "deps"
    ".venv"
    ".direnv"
    ".elixir_ls"
  ];
  skipPaths = [
    "/data/clickhouse"
    "/data/server/osm"
    "/data/server/fts/base-config/Logs"
    "/data/minecraft/vanilla/plugins/Backuper"
    "/data/minecraft/gtnh/backups"
    "/home/sgiath/.local/share/pnpm"
    "/home/sgiath/.npm"
    "/home/sgiath/.t3/runtime"
    "/home/sgiath/.t3/tools"
    "/home/sgiath/develop/crazyegg/ce-local-infra/tmp"
    "/root/.npm"
    "/var/lib/containers"
    "/var/lib/docker"
    "/var/lib/foundryvtt/container_cache"
    "/var/lib/jellyfin/metadata"
    "/var/lib/pihole"
    "/var/lib/pihole.podman-bak"
    "/var/lib/private/opentelemetry-collector"
    "/var/lib/transmission"
    matrixState
  ];

  prepare = pkgs.writeShellApplication {
    name = "offsite-backup-prepare";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.sqlite
      pkgs.systemd
    ];
    text = ''
      rm -rf ${staging}/sqlite ${staging}/continuwuity
      mkdir -p ${staging}/sqlite
      chmod 700 ${staging}
      : >${staging}/live-databases

      # Online backups are consistent snapshots even while the owner writes;
      # -readonly never creates -wal/-shm files the service could not open.
      find ${lib.escapeShellArgs (lib.remove staging paths)} -xdev \
        \( -type d \( ${
          lib.concatMapStringsSep " -o " (name: "-name ${lib.escapeShellArg name}") skipNames
        } -o ${
          lib.concatMapStringsSep " -o " (path: "-path ${lib.escapeShellArg path}") skipPaths
        } \) -prune \) -o \
        -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -size +0 -print0 |
        while IFS= read -r -d "" db; do
          header="$(head -c 15 "$db")"
          if [[ "$header" != "SQLite format 3" ]]; then
            continue
          fi
          copy="${staging}/sqlite$db"
          mkdir -p "$(dirname "$copy")"
          sqlite3 -readonly "$db" ".backup \"$copy\""
          printf '%s\n' "$db" "$db-wal" "$db-shm" "$db-journal" >>${staging}/live-databases
        done

      # RocksDB has no online copy through the filesystem; Matrix is down for
      # the few seconds of the copy and starts again whatever happens.
      trap 'systemctl start continuwuity.service' EXIT
      systemctl stop continuwuity.service
      cp -a --reflink=auto ${matrixState} ${staging}/continuwuity
    '';
  };
in
{
  sops.secrets = {
    restic_offsite_password = { };
    restic_offsite_rest_env = { };
  };

  services.restic.backups.offsite = {
    repository = "rest:http://${hygiea.ip4}:8000/vesta/";
    environmentFile = config.sops.secrets.restic_offsite_rest_env.path;
    passwordFile = config.sops.secrets.restic_offsite_password.path;
    initialize = true;
    inherit paths;
    exclude = skipPaths ++ map (name: "**/${name}") skipNames ++ [ "/var/backup/agent-archive/*.tmp" ];
    extraBackupArgs = [
      "--exclude-caches"
      "--exclude-file=${staging}/live-databases"
      "--compression=max"
    ];
    backupPrepareCommand = lib.getExe prepare;
    # Append-only: forget/prune would fail here and runs on Ceres instead.
    pruneOpts = [ ];
    # After the agent archive's midnight Parquet export.
    timerConfig = {
      OnCalendar = "03:30";
      RandomizedDelaySec = "20min";
      Persistent = true;
    };
  };

  systemd.services.restic-backups-offsite = {
    onFailure = [ "notify-failure@%n.service" ];
    serviceConfig = {
      # The first run uploads everything; later runs take minutes.
      TimeoutStartSec = "12h";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
}
