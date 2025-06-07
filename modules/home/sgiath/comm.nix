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
      signal-desktop-bin
      # cinny-desktop
      # fractal
      # simplex-chat-desktop
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${pkgs.webcord}/bin/webcord"
        "${pkgs.telegram-desktop}/bin/telegram-desktop"
        "${pkgs.signal-desktop-bin}/bin/signal-desktop"
        # "${pkgs.cinny-desktop}/bin/cinny"
        # "${pkgs.fractal}/bin/fractal"
      ];
      windowrulev2 = [
        "workspace 10 silent, class:(Slack)"
        "workspace 10 silent, class:(WebCord)"
        "workspace 10 silent, class:(signal)"
        "workspace 10 silent, class:(org.telegram.desktop)"
        "workspace 10 silent, class:(Hexchat)"
        "workspace 10 silent, class:(cinny)"
        "workspace 10 silent, class:(org.gnome.Fractal)"
      ];
    };
  };
}
