{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  config = lib.mkIf config.programs.hyprland.enable {
    programs.noctalia-shell = {
      enable = true;
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
              { id = "Workspace"; }
            ];
            center = [
              { id = "ActiveWindow"; }
              { id = "MediaMini"; }
            ];
            right = [
              { id = "SystemMonitor"; }
              { id = "Clock"; }
              { id = "Tray"; }
              { id = "NotificationHistory"; }
              { id = "Battery"; }
              { id = "Volume"; }
              { id = "Brightness"; }
              { id = "ControlCenter"; }
            ];
          };
        };

        general = {
          avatarImage = "/home/sgiath/Pictures/profile/cyborg_cowboy_head.jpg";
          clockFormat = "hhmmss";
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
          screen-toolkit = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          zed-provider = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          model-usage = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
      };
    };

    wayland.windowManager.hyprland.settings = {
      "$ipc" = "${lib.getExe pkgs.quickshell} -c ${lib.getExe pkgs.noctalia-shell} ipc call";
      # exec-once = [ "${lib.getExe pkgs.quickshell} -c ${lib.getExe pkgs.noctalia-shell}" ];
      bind = [
        "$mod SHIFT, Q, exec, $ipc sessionMenu toggle"
        "$mod, slash, exec, $ipc launcher toggle"
        "$mod, B, exec, $ipc launcher windows"
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
