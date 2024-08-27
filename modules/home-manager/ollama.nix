{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.ollama = {
    enable = lib.mkEnableOption "ollama";
  };

  config = lib.mkIf config.services.ollama.enable {
    systemd.user.services.ollama = {
      Unit = {
        Description = "Ollama Service";
        After = "network-online.target";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        ExecStart = "${pkgs.ollama}/bin/ollama serve";
        Restart = "always";
        RestartSec = 3;
      };
    };
  };
}
