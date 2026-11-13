{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The CrazyEgg home repository (~/develop/crazyegg/home) is checked out on
  # every CrazyEgg machine and shares one hub repository on Vesta; bin/sync
  # merges the hub into the checkout and pushes local commits.
  homeRepo = "${config.home.homeDirectory}/develop/crazyegg/home";
in
{
  config = lib.mkIf config.sgiath.work.crazyegg.enable {
    home.packages = lib.optionals config.sgiath.roles.desktop.enable [
      pkgs.google-chrome
    ];

    systemd.user.services.crazyegg-home-sync = {
      Unit = {
        Description = "Sync the CrazyEgg home repository with its hub";
        ConditionPathExists = "${homeRepo}/bin/sync";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${homeRepo}/bin/sync --quiet";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.coreutils
              pkgs.diffutils
              pkgs.findutils
              pkgs.gawk
              pkgs.git
              pkgs.gnugrep
              pkgs.gnupg
              pkgs.gnused
              pkgs.openssh
              pkgs.python3
              pkgs.util-linux
            ]
          }"
          "SSH_AUTH_SOCK=%t/gnupg/S.gpg-agent.ssh"
        ];
        # bin/sync waits up to 5 min for the save lock, then fetch, signing and
        # push each have their own timeouts.
        TimeoutStartSec = "15min";
      };
    };
    systemd.user.timers.crazyegg-home-sync = {
      Unit.Description = "Sync the CrazyEgg home repository every 2 minutes";
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "2min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
