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
      # webcord
      telegram-desktop
      signal-desktop
      # simplex-chat-desktop
      gajim
      weechat
      cinny-desktop

      # nostr CLI
      pkgs.${namespace}.nak
    ];

    programs = {
      element-desktop = {
        enable = true;
        settings = {
          default_server_config = {
            "m.homeserver" = {
              base_url = "https://matrix.sgiath.dev";
              server_name = "sgiath.dev";
            };
          };

          features = {
            feature_latex_maths = true;
            feature_pinning = true;
            feature_dm_verification = true;
            feature_location_share_live = true;
            feature_video_rooms = true;
            feature_element_call_video_rooms = true;
            feature_group_calls = true;
            feature_new_room_list = true;
          };

          disable_custom_urls = false;
          disable_login_language_selector = false;
          force_verification = true;

          default_theme = "dark";
          brand = "matrix";
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # "${lib.getExe pkgs.webcord}"
        # "${lib.getExe pkgs.telegram-desktop}"
        "${lib.getExe pkgs.signal-desktop}"
        "${lib.getExe pkgs.cinny-desktop}"
      ];
      windowrule = [
        "match:class Slack, workspace 10 silent, no_initial_focus on"
        "match:class WebCord, workspace 10 silent, no_initial_focus on"
        "match:class signal, workspace 10 silent, no_initial_focus on"
        "match:class org.telegram.desktop, workspace 10 silent, no_initial_focus on"
        "match:class Hexchat, workspace 10 silent, no_initial_focus on"
        "match:class fluffychat, workspace 10 silent, no_initial_focus on"
        "match:class Element, workspace 10 silent, no_initial_focus on"
        "match:class cinny, workspace 10 silent, no_initial_focus on"
      ];
    };
  };
}
