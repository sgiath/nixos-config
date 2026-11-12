# Retention for Vesta's offsite repository on Hygiea. Vesta writes through an
# append-only REST server and cannot delete; Ceres holds the only credential
# that can (an SFTP key for Hygiea's restic user, in secrets/ceres.yaml, which
# Vesta cannot decrypt). Pruning and checking run here, with the repository
# password, so Hygiea never decrypts anything.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  hygiea = "hygiea.${config.sgiath.nebula.domain}";
  restic = "${lib.getExe pkgs.restic} -o sftp.command='ssh -i ${config.sops.secrets.restic_offsite_ssh_key.path} -o IdentitiesOnly=yes restic@${hygiea} -s sftp'";

  # --keep-within counts back from the newest snapshot, and Vesta, the
  # writer, chooses snapshot times. A snapshot dated in the future would let
  # a compromised Vesta age every real one out of the window, so refuse to
  # forget anything while one exists. Fake snapshots with plausible times are
  # harmless: everything from the last 30 days is kept.
  futureGuard = pkgs.writeShellApplication {
    name = "offsite-prune-future-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.openssh
    ];
    text = ''
      latest="$(${restic} snapshots --json --no-lock | jq -r 'map(.time) | max // empty')"
      if [[ -n "$latest" ]] && (($(date -d "$latest" +%s) > $(date +%s) + 3600)); then
        echo "newest snapshot is dated $latest, in the future; not forgetting anything" >&2
        exit 1
      fi
    '';
  };
in
{
  sops.secrets = {
    restic_offsite_password.sopsFile = ../../../secrets/ceres.yaml;
    restic_offsite_ssh_key.sopsFile = ../../../secrets/ceres.yaml;
  };

  programs.ssh.knownHosts.${hygiea}.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqJzng5fcIvKrHi1B+OxTklNJeUrMtRXwV2CWJxZbye";

  services.restic.backups.offsite-prune = {
    repository = "sftp:restic@${hygiea}:/var/lib/restic/vesta";
    passwordFile = config.sops.secrets.restic_offsite_password.path;
    paths = [ ];
    backupPrepareCommand = lib.getExe futureGuard;
    timerConfig = {
      OnCalendar = "Sun 06:00";
      Persistent = true;
    };
  };

  # The module's `forget --prune` prunes only when a snapshot was forgotten;
  # prune every week so packs left by interrupted uploads go too. unlock
  # clears locks those uploads could not delete through the append-only
  # server.
  systemd.services.restic-backups-offsite-prune.serviceConfig.ExecStart = lib.mkForce [
    "${restic} unlock"
    "${restic} forget --keep-within 30d --keep-monthly 12"
    "${restic} prune"
    "${restic} check --read-data-subset=5%"
  ];
}
