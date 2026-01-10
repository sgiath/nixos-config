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
      # webcord
      telegram-desktop
      signal-desktop-bin
      mattermost-desktop
      # cinny-desktop
      fractal
      simplex-chat-desktop
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # "${pkgs.webcord}/bin/webcord"
        "${pkgs.telegram-desktop}/bin/telegram-desktop"
        "${pkgs.signal-desktop-bin}/bin/signal-desktop"
        # "${pkgs.cinny-desktop}/bin/cinny"
        # "${pkgs.fractal}/bin/fractal"
      ];
      windowrule = [
        "match:class Slack, workspace 10 silent, no_initial_focus on"
        "match:class WebCord, workspace 10 silent, no_initial_focus on"
        "match:class signal, workspace 10 silent, no_initial_focus on"
        "match:class org.telegram.desktop, workspace 10 silent, no_initial_focus on"
        "match:class Hexchat, workspace 10 silent, no_initial_focus on"
        "match:class cinny, workspace 10 silent, no_initial_focus on"
        "match:class org.gnome.Fractal, workspace 10 silent, no_initial_focus on"
      ];
    };

    programs = {
      newsboat = {
        enable = true;
        autoReload = true;
      };
    };
  };
}
