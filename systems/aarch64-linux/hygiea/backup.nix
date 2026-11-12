# Offsite target for Vesta's encrypted restic snapshots
# (systems/x86_64-linux/vesta/offsite-backup.nix). Append-only, so a
# compromised Vesta cannot delete history; Hygiea never holds the repository
# password. Ceres prunes and checks the repository over SFTP as the restic
# user (systems/x86_64-linux/ceres/offsite-prune.nix).
{ config, ... }:
let
  port = 8000;
in
{
  sops.secrets.restic_htpasswd = {
    owner = "restic";
    group = "restic";
    mode = "0400";
    restartUnits = [ "restic-rest-server.service" ];
  };

  services.restic.server = {
    enable = true;
    listenAddress = "${config.sgiath.nebula.peers.hygiea.ip4}:${toString port}";
    appendOnly = true;
    # Each user reaches only /var/lib/restic/<user>; Vesta is user `vesta`.
    privateRepos = true;
    htpasswd-file = config.sops.secrets.restic_htpasswd.path;
    # The repository shares the root filesystem; stop accepting data before
    # it fills the 200 GB disk.
    extraFlags = [
      "--max-size"
      (toString (140 * 1000 * 1000 * 1000))
    ];
  };

  networking.firewall.interfaces."nebula.sgiath".allowedTCPPorts = [ port ];

  users.users.restic.openssh.authorizedKeys.keys = [
    ''restrict,command="internal-sftp" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICyfmobKgzw55kGeA/DJAuWTKC5M+8W8MtCnqttUZoBx restic-prune@ceres''
  ];
}
