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
    };

    wayland.windowManager.hyprland.settings = {
      exec-once = [ "${lib.getExe pkgs.noctalia-shell}" ];
      "$ipc" = "noctalia-shell ipc call";
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
