{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.programs.hyprland = {
    enable = lib.mkEnableOption "hyprland";
  };

  config = lib.mkIf config.programs.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      xwayland.enable = true;
      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [ "--all" ];
      };

      settings = {
        decoration.rounding = 5;

        input = {
          touchpad.natural_scroll = true;
          tablet.output = "current";
        };

        group.groupbar.font_size = 14;
        misc.focus_on_activate = true;

        monitor = [
          # Desktop
          "DP-1,highres,0x2560,1"
          "DP-3,highres,0x1120,1"
          "DP-2,highres,3440x0,1,transform,1"

          # Notebook
          "eDP-1,2560x1600@240,0x0,1"
        ];

        master = {
          # mfact = 0.66;
          orientation = "right";
        };

        # bindings
        "$mod" = "SUPER";
        bind = [
          "$mod SHIFT, Q, exec, ${pkgs.wlogout}/bin/wlogout"

          "$mod SHIFT, C, killactive,"
          "$mod, R, togglesplit,"
          "$mod, F, togglefloating, active"
          "$mod SHIFT, Space, fullscreen, 0"

          # move focus
          "$mod, H, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, K, movefocus, u"
          "$mod, J, movefocus, d"

          "$mod, left, workspace, r-1"
          "$mod, right, workspace, r+1"

          # go to workspace
          "$mod, grave, togglespecialworkspace, special"
          "$mod, 1, focusworkspaceoncurrentmonitor, 1"
          "$mod, 2, focusworkspaceoncurrentmonitor, 2"
          "$mod, 3, focusworkspaceoncurrentmonitor, 3"
          "$mod, 4, focusworkspaceoncurrentmonitor, 4"
          "$mod, 5, focusworkspaceoncurrentmonitor, 5"
          "$mod, 6, focusworkspaceoncurrentmonitor, 6"
          "$mod, 7, focusworkspaceoncurrentmonitor, 7"
          "$mod, 8, focusworkspaceoncurrentmonitor, 8"
          "$mod, 9, focusworkspaceoncurrentmonitor, 9"
          "$mod, 0, focusworkspaceoncurrentmonitor, 10"

          # move to workspace
          "$mod SHIFT, grave, movetoworkspace, special"
          "$mod SHIFT, 1, movetoworkspace, 1"
          "$mod SHIFT, 2, movetoworkspace, 2"
          "$mod SHIFT, 3, movetoworkspace, 3"
          "$mod SHIFT, 4, movetoworkspace, 4"
          "$mod SHIFT, 5, movetoworkspace, 5"
          "$mod SHIFT, 6, movetoworkspace, 6"
          "$mod SHIFT, 7, movetoworkspace, 7"
          "$mod SHIFT, 8, movetoworkspace, 8"
          "$mod SHIFT, 9, movetoworkspace, 9"
          "$mod SHIFT, 0, movetoworkspace, 10"

          "$mod, G, togglegroup,"
          "$mod SHIFT, H, moveintogroup, l"
          "$mod SHIFT, J, moveintogroup, d"
          "$mod SHIFT, K, moveintogroup, u"
          "$mod SHIFT, L, moveintogroup, r"
        ];

        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod SHIFT, mouse:272, resizewindow"
        ];

        workspace = [
          "1,monitor:DP-1,default:true,persistent:true"
          "2,monitor:DP-3,default:true,persistent:true"
          "3,monitor:DP-3,persistent:true"
          "4,monitor:DP-1,persistent:true"
          "5,monitor:DP-3,persistent:true"
          "6,monitor:DP-1,persistent:true"
          "7,monitor:DP-3,persistent:true"
          "8,monitor:DP-3,persistent:true"
          "9,monitor:DP-3,persistent:true"
          "10,monitor:DP-2,default:true,gapsin:0,gapsout:0,border:false,persistent:true"
        ];
      };
    };

    gtk = pkgs.lib.mkForce {
      enable = true;
      theme = {
        package = pkgs.flat-remix-gtk;
        name = "Flat-Remix-GTK-Grey-Darkest";
      };
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };
    };

    home = {
      packages = with pkgs; [
        (writeShellScriptBin "screenshot" ''
          ${grim}/bin/grim -g "$(${slurp}/bin/slurp)" - | ${swappy}/bin/swappy -f -
        '')
      ];
    };

    programs.wofi = {
      enable = true;
      settings = {
        mode = "drun";
        prompt = "";
        insensitive = true;
      };
    };

    services = {
      hyprpaper = {
        enable = true;
        settings = lib.mkForce {
          preload = [ "${./wallpapers/transhumanism.png}" ];
          wallpaper = [
            "DP-1,contain:${./wallpapers/transhumanism.png}"
            "DP-3,contain:${./wallpapers/transhumanism.png}"
            "DP-2,contain:${./wallpapers/transhumanism.png}"
          ];
        };
      };
      mako.enable = true;
      hyprpolkitagent.enable = true;
    };
  };
}
