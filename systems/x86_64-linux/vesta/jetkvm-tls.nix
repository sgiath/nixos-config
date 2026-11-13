# HTTPS for the JetKVM web UIs: one ACME certificate per KVM
# (<kvm>.nebula.sgiath.dev, DNS-01 through Cloudflare like every other
# certificate here), installed on the device by jetkvm-tls.py through JetKVM's RPC.
# Per-KVM certificates put the names into CT logs, but a wildcard would give
# each KVM a key valid for every *.nebula.sgiath.dev host. HTTP stays on for
# recovery and access by IP.
#
# The sync runs after each issuance or renewal and daily, so a KVM that was
# offline catches up; it pushes only when the served certificate differs,
# because the push replaces any open KVM session.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  nebula = config.sgiath.nebula;
  # FIXME: list kvm-vesta here once Nebula runs on it (scripts/nebula-jetkvm.sh);
  # a KVM without Nebula would fail every sync.
  kvms = [ "kvm-ceres" ];
  domain = name: "${name}.${nebula.domain}";

  sync = pkgs.writers.writePython3Bin "jetkvm-tls-sync" {
    libraries = with pkgs.python3Packages; [
      aiortc
      websockets
    ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./jetkvm-tls.py);
in
{
  users.groups.jetkvm-tls = { };

  security.acme.certs = lib.genAttrs (map domain kvms) (_: {
    group = "jetkvm-tls";
    postRun = "${lib.getExe' config.systemd.package "systemctl"} --no-block start jetkvm-tls-sync.service";
  });

  systemd.services.jetkvm-tls-sync = {
    description = "Install HTTPS certificates on the JetKVMs";
    after = [ "nebula@sgiath.service" ] ++ map (name: "acme-${domain name}.service") kvms;
    wants = [ "nebula@sgiath.service" ];
    onFailure = [ "notify-failure@%n.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.escapeShellArgs (
        [
          (lib.getExe sync)
          nebula.peers.vesta.ip4
        ]
        ++ map (name: "${domain name}=${nebula.peers.${name}.ip4}=/var/lib/acme/${domain name}") kvms
      );
      DynamicUser = true;
      SupplementaryGroups = [ "jetkvm-tls" ];
      TimeoutStartSec = "10min";
    };
  };

  systemd.timers.jetkvm-tls-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
