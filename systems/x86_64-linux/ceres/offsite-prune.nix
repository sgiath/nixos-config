# Retention for Vesta's offsite repository on Hygiea. Vesta writes through an
# append-only REST server and cannot delete; Ceres holds the only credential
# that can (an SFTP key for Hygiea's restic user, in secrets/ceres.yaml, which
# Vesta cannot decrypt). Pruning and checking run here, with the repository
# password, so Hygiea never decrypts anything.
{ config, ... }:
let
  hygiea = "hygiea.${config.sgiath.nebula.domain}";
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
    extraOptions = [
      "sftp.command='ssh -i ${config.sops.secrets.restic_offsite_ssh_key.path} -o IdentitiesOnly=yes restic@${hygiea} -s sftp'"
    ];
    paths = [ ];
    # --keep-within keeps every snapshot of the last 30 days, so a
    # compromised Vesta cannot push enough fake snapshots to rotate out the
    # good ones before someone notices.
    pruneOpts = [
      "--keep-within 30d"
      "--keep-monthly 12"
    ];
    runCheck = true;
    checkOpts = [ "--read-data-subset=5%" ];
    timerConfig = {
      OnCalendar = "Sun 06:00";
      Persistent = true;
    };
  };
}
