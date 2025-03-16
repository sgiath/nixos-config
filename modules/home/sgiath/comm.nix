{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.comm = {
    enable = lib.mkEnableOption "communication apps";
  };

  config = lib.mkIf (config.sgiath.comm.enable) {
    home.packages = with pkgs; [
      webcord
      telegram-desktop
      signal-desktop
      cinny-desktop
      fractal
      simplex-chat-desktop
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${pkgs.webcord}/bin/webcord"
        "${pkgs.telegram-desktop}/bin/telegram-desktop"
        "${pkgs.signal-desktop}/bin/signal-desktop"
        "${pkgs.cinny-desktop}/bin/cinny"
        "${pkgs.fractal}/bin/fractal"
      ];
    };
  };
}
