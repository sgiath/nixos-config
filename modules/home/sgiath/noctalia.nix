{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.noctalia-shell.enable {
    home.packages = with pkgs; [
      grim
      imagemagick
      wl-clipboard
      satty
      swappy
    ];

    programs.noctalia-shell = {
      systemd.enable = true;
      settings = {
        bar = {
          density = "spacious";
          monitors = [
            "DP-1"
            "DP-3"
          ];
          widgets = {
            left = [
              { id = "Launcher"; }
              { id = "ActiveWindow"; }
              { id = "MediaMini"; }
            ];
            center = [
              {
                id = "Workspace";
                occupiedColor = "tertiary";
                showLabelsOnlyWhenOccupied = false;
                pillSize = 0.75;
              }
              { id = "plugin:model-usage"; }
              { id = "plugin:screen-shot-and-record"; }
            ];
            right = [
              { id = "SystemMonitor"; }
              { id = "NotificationHistory"; }
              { id = "Battery"; }
              { id = "Volume"; }
              { id = "Clock"; }
              { id = "Tray"; }
              { id = "ControlCenter"; }
            ];
          };
        };

        general = {
          avatarImage = "/home/sgiath/Pictures/profile/cyborg_cowboy_head.jpg";
          clockFormat = "HH:mm:ss yyyy-MM-dd";
        };

        location = {
          monthBeforeDay = true;
          name = "Ostrava, Czechia";
        };

        appLauncher = {
          pinnedApps = [
            "chromium-browser"
            "google-chrome"
            "firefox"
          ];
          terminalCommand = "${lib.getExe pkgs.kitty} -e";
        };

        dock = {
          size = 2;
          onlySameOutput = false;
          monitors = [ "DP-1" ];
        };

        notifications = {
          monitors = [ "DP-1" ];
        };
      };

      plugins = {
        version = 2;
        sources = [
          {
            enabled = true;
            name = "Official Noctalia Plugins";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          zed-provider = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          model-usage = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          screen-shot-and-record = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
      };
      pluginSettings = {
        screen-shot-and-record = {
          screenshotEditor = lib.getExe pkgs.swappy;
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      "$ipc" = "${lib.getExe pkgs.noctalia-shell} ipc call";
      bind = [
        "$mod SHIFT, Q, exec, $ipc sessionMenu toggle"
        "$mod, slash, exec, $ipc launcher toggle"
        "$mod, B, exec, $ipc launcher windows"
        "$mod, S, exec, $ipc plugin:screen-shot-and-record screenshot"
      ];

      layerrule = [
        {
          name = "noctalia";
          "match:namespace" = "noctalia-background-.*$";
          ignore_alpha = 0.5;
          blur = true;
          blur_popups = true;
        }
      ];
    };
  };
}
