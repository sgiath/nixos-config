{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.system-failure-watcher;

  watcher = pkgs.writeShellApplication {
    name = "system-failure-watcher";
    runtimeInputs = [
      pkgs.herdr
      pkgs.jq
      pkgs.omp
      pkgs.systemd
      pkgs.tmux
    ];
    text = builtins.readFile ./system-failure-watcher.sh;
  };
in
{
  options.services.system-failure-watcher.enable = lib.mkEnableOption "automatic OMP investigation of service failures and application crashes";

  config = lib.mkIf cfg.enable {
    systemd.user.services.system-failure-watcher = {
      Unit.Description = "Open OMP investigations for service failures and application crashes";

      Service = {
        ExecStart = lib.getExe watcher;
        Restart = "always";
        RestartSec = 5;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
