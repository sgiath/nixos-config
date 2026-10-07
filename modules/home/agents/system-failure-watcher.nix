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
      config.services.t3code.package
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = builtins.readFile ./system-failure-watcher.sh;
  };
in
{
  options.services.system-failure-watcher.enable = lib.mkEnableOption "automatic T3 investigation of service failures and application crashes";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.t3code.enable;
        message = "system-failure-watcher requires services.t3code.enable";
      }
    ];

    systemd.user.services.system-failure-watcher = {
      Unit = {
        Description = "Open T3 investigations for service failures and application crashes";
        After = [ "t3code.service" ];
        Wants = [ "t3code.service" ];
      };

      Service = {
        ExecStart = lib.getExe watcher;
        Restart = "always";
        RestartSec = 5;
        Environment = [
          "SYSTEM_FAILURE_WATCHER_T3_ENDPOINT=http://${config.services.t3code.host}:${toString config.services.t3code.port}/mcp"
        ];
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
