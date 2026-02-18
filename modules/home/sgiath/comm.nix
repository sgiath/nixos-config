{
  config,
  lib,
  pkgs,
  namespace,
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
      # mattermost-desktop
      # simplex-chat-desktop
      fluffychat

      # nostr CLI
      pkgs.${namespace}.nak
    ];

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "${pkgs.webcord}/bin/webcord"
        "${pkgs.telegram-desktop}/bin/telegram-desktop"
        "${pkgs.signal-desktop-bin}/bin/signal-desktop"
        "${pkgs.fluffychat}/bin/fluffychat"
      ];
      windowrule = [
        "match:class Slack, workspace 10 silent, no_initial_focus on"
        "match:class WebCord, workspace 10 silent, no_initial_focus on"
        "match:class signal, workspace 10 silent, no_initial_focus on"
        "match:class org.telegram.desktop, workspace 10 silent, no_initial_focus on"
        "match:class Hexchat, workspace 10 silent, no_initial_focus on"
        "match:fluffychat FluffyChat, workspace 10 silent, no_initial_focus on"
      ];
    };
  };
}
