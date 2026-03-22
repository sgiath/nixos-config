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
    };
    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "qs -c noctalia-shell"
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
