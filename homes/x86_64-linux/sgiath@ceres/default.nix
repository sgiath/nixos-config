{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  eveFlipper = pkgs.${namespace}.eve-flipper;
in
{
  home.packages = with pkgs; [
    texliveMedium
    # lmstudio
    # davinci-resolve-studio
    # whisper-cpp-vulkan
  ];

  systemd.user.services.eve-flipper = {
    Unit = {
      Description = "EVE Flipper local web app";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Restart = "always";
      RestartSec = 5;
      KillMode = "process";
      WorkingDirectory = "${config.xdg.dataHome}/eve-flipper";
      Environment = [
        "HOME=${config.home.homeDirectory}"
      ];
      ExecStart = "${lib.getExe eveFlipper} --host 127.0.0.1 --port 13370";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  sgiath = {
    enable = true;
    games.enable = true;
    agents.aoe.serve.enable = true;

    targets = {
      terminal = true;
      graphical = true;
    };
  };

  crazyegg.enable = true;

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
