{
  config,
  lib,
  pkgs,
  ...
}:
let
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
  # Vesta. Sources and cursors are described in archive/ship.py.
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
