{
  config,
  lib,
  pkgs,
  ...
}:
let 
  screenshot = pkgs.writeShellScriptBin "screenshot" ''
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.swappy}/bin/swappy -f -
  '';
in 
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
        # colors
        general = {
          "col.active_border" = "rgba(F7DCDE39)";
          "col.inactive_border" = "rgba(A58A8D30)";
        };
        misc.background_color = "rgba(1D1011FF)";

        # general
        general = {
          gaps_in = 4;
          gaps_out = 5;
          gaps_workspaces = 50;
      
          border_size = 1;
          resize_on_border = true;
          no_focus_fallback = true;
          allow_tearing = true;
      
          snap = {
          	enabled = true;
          	window_gap = 4;
          	monitor_gap = 5;
          	respect_gaps = true;
          };
        };

dwindle = {
    preserve_split = true;
    smart_split = false;
    smart_resizing = false;
    # precise_mouse_move = true
};

decoration = {
    rounding = 18;

    blur = {
        enabled = true;
        xray = true;
        special = false;
        new_optimizations = true;
        size = 10;
        passes = 3;
        brightness = 1;
        noise = 0.15;
        contrast = 0.2;
        vibrancy = 0.8;
        vibrancy_darkness = 0.8;
        popups = false;
        popups_ignorealpha = 0.6;
        input_methods = true;
        input_methods_ignorealpha = 0.8;
    };

    shadow = {
        enabled = true;
        ignore_window = true;
        range = 30;
        offset = "0 2";
        render_power = 4;
        color = "rgba(00000010)";
    };

    # Dim
    dim_inactive = true;
    dim_strength = 0.025;
    dim_special = 0.07;
};




        input = {
          touchpad.natural_scroll = true;
          tablet.output = "current";
        };

        group.groupbar.font_size = 14;
        misc.focus_on_activate = true;

        monitor = [
          # Desktop
          "DP-1,5120x1440@240,0x2560,1"
          "DP-3,3440x1440@165,0x1120,1"
          "DP-2,2560x1440@165,3440x0,1,transform,1"

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
          "$mod, S, exec, ${screenshot}/bin/screenshot"

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
          "$mod, grave, togglespecialworkspace, special:nasa"
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
          "$mod SHIFT, grave, movetoworkspace, special:nasa"
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
    stylix.targets.hyprland.enable = false;

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

    home.packages = [ screenshot pkgs.grim ];

    programs.wofi = {
      enable = true;
      settings = {
        mode = "drun";
        prompt = "";
        insensitive = true;
      };
    };

    services = {
      mako.enable = true;
      hyprpolkitagent.enable = true;
    };
  };
}
