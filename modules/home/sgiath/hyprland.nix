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
    stylix.targets.hyprland.enable = false;
    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      # portalPackage = pkgs.xdg-desktop-portal-hyprland;
      xwayland.enable = true;
      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [ "--all" ];
      };

      settings = {
        # startup
        exec-once = [
          "${pkgs.kitty}/bin/kitty"
          # "${pkgs.ungoogled-chromium}/bin/chromium"
          # "${pkgs.freetube}/bin/freetube"
          "${pkgs.obsidian}/bin/obsidian"
          "${pkgs.protonmail-desktop}/bin/proton-mail"
          "${pkgs.slack}/bin/slack"
          "${pkgs.webcord}/bin/webcord"
          "${pkgs.cinny-desktop}/bin/cinny"
          "${pkgs.signal-desktop-beta}/bin/signal-desktop-beta"
          "${pkgs.telegram-desktop}/bin/telegram-desktop"
        ];

        monitor = [
          # Desktop
          "DP-1,highres,0x2560,1"
          "DP-3,highres,0x1120,1"
          "DP-2,highres,3440x0,1,transform,1"

          # Notebook
          "eDP-1,2560x1600@240,0x0,1"
        ];

        input.touchpad.natural_scroll = true;

        master = {
          mfact = 0.66;
          orientation = "right";
        };

        # bindings
        "$mod" = "SUPER";
        bind = [
          "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
          "$mod, slash, exec, ${pkgs.wofi}/bin/wofi --show drun"
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
          "6,monitor:DP-3,persistent:true"
          "7,monitor:DP-3,persistent:true"
          "8,monitor:DP-3,persistent:true"
          "9,monitor:DP-3,persistent:true"
          "10,monitor:DP-2,default:true,gapsin:0,gapsout:0,border:false,persistent:true"
        ];

        # hyprctl clients
        windowrulev2 = [
          # terminal in special workspace
          "workspace 1, class:(kitty)"

          # browsers
          "workspace 2 silent, class:(chromium-browser)"
          "workspace 3 silent, class:(google-chrome)"
          "workspace 4 silent, class:(firefox)"

          # other apps
          "workspace 5 silent, class:(obsidian)"
          "workspace 6 silent, class:(.factorio-wrapped)"

          # email
          "workspace 9 silent, class:(claws-mail)"
          "workspace 9 silent, class:(Proton Mail)"

          # messaging apps
          "workspace 10 silent, class:(Slack)"
          "workspace 10 silent, class:(WebCord)"
          "workspace 10 silent, class:(signalbeta)"
          "workspace 10 silent, class:(org.telegram.desktop)"
          "workspace 10 silent, class:(Hexchat)"
          "workspace 10 silent, class:(cinny)"
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
      pointerCursor.gtk.enable = true;

      packages = with pkgs; [
        (writeShellScriptBin "screenshot" ''
          ${grim}/bin/grim -g "$(${slurp}/bin/slurp)" - | ${swappy}/bin/swappy -f -
        '')
        wl-clipboard
        wl-clipboard-x11
        wlogout
      ];
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
      };
    };

    programs.wofi.enable = true;
    services.mako.enable = true;

    xdg = {
      portal = {
        enable = true;
        config.common.default = "hyprland";
        xdgOpenUsePortal = true;
        # configPackages = [
        #   pkgs.xdg-desktop-portal-hyprland
        #   pkgs.xdg-desktop-portal-gtk
        # ];
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      };
    };
  };
}
