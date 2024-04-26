{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.hyprland.homeManagerModules.default ];

  options.sgiath.hyprland = {
    enable = lib.mkEnableOption "hyprland";
  };

  config = lib.mkIf config.sgiath.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;

      settings = {
        # startup
        exec-once = [
          "${pkgs.kitty}/bin/kitty"
          # "${pkgs.ungoogled-chromium}/bin/chromium"
          "${pkgs.claws-mail}/bin/claws-mail"
          "${pkgs.slack}/bin/slack"
          "${pkgs.webcord}/bin/webcord"
        ];

        monitor = [
          "DP-1,highres,0x2560,1"
          "DP-3,highres,0x1120,1"
          "DP-2,highres,3440x0,1,transform,1"
        ];

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

        windowrulev2 = [
          # terminal in special workspace
          "workspace 1, class:(kitty)"

          # browsers
          "workspace 2 silent, class:(Chromium-browser)"
          "workspace 3 silent, class:(Google-chrome)"
          "workspace 4 silent, class:(firefox)"

          # email
          "workspace 9 silent, class:(claws-mail)"

          # messaging apps
          "workspace 10 silent, class:(Slack)"
          "workspace 10 silent, class:(WebCord)"
          "workspace 10 silent, class:(TelegramDesktop)"
        ];
      };
    };

    home = {
      packages = with pkgs; [
        (writeShellScriptBin "screenshot" ''
          ${grim}/bin/grim -g "$(${slurp}/bin/slurp)" - | ${swappy}/bin/swappy -f -
        '')
        wl-clipboard-rs
        wlogout
      ];
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
      };
    };

    programs = {
      waybar = {
        enable = true;
        systemd.enable = true;
        settings = {
          mainBar = {
            height = 36;
            spacing = 16;
            output = [
              "DP-1"
              "DP-3"
            ];
            modules-left = [ "hyprland/workspaces" ];
            modules-right = [
              "network"
              "network#2"
              "memory"
              "cpu"
              "clock"
              "custom/wlogout"
              "tray"
            ];

            network = {
              interface = "enp56s0";
              format = "{ipaddr}: {bandwidthUpBytes} / {bandwidthDownBytes}";
            };
            "network#2" = {
              interface = "enp58s0";
              format = "{ipaddr}: {bandwidthUpBytes} / {bandwidthDownBytes}";
            };
            memory = {
              format = "RAM: {used} GiB / {total} GiB";
            };
            cpu = {
              format = "CPU: {usage}% ({max_frequency}GHz)";
            };
            clock = {
              format = "{:%Y-%m-%d %H%M}";
            };

            "custom/logout" = {
              exec = "wlogout";
              format = "logout";
            };

            "hyprland/workspaces" = {
              format = "{icon}";
              format-icons = {
                "1" = "term";
                "2" = "web";
                "3" = "work";
                "4" = "firefox";
                "5" = "5";
                "6" = "6";
                "7" = "7";
                "8" = "8";
                "9" = "mail";
                "10" = "chat";
              };
            };
          };
        };
      };
      wofi = {
        enable = true;
      };
    };

    services.mako = {
      enable = true;
    };

    xdg = {
      portal = {
        enable = true;
        config.common.default = "hyprland";
        xdgOpenUsePortal = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      };
    };
  };
}
