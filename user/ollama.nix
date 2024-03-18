 { pkgs, ... }:

 {
  home.packages = [
    pkgs.ollama
  ];

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
 }
