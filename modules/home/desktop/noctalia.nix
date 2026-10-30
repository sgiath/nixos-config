{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.noctalia.enable {
    programs.noctalia = {
      systemd.enable = true;

      settings = {
        shell = {
          avatar_path = "/home/sgiath/Pictures/profile/cyborg_cowboy_head.jpg";
          time_format = "{:%H:%M:%S}";
          date_format = "%Y-%m-%d";
          launch_apps_as_systemd_services = true;

          launcher.pinned = [
            "chromium-browser"
            "google-chrome"
            "firefox"
          ];
        };

        location.address = "Ostrava, Czechia";
        weather.enabled = true;

        bar.main = {
          enabled = false;
          thickness = 47;
          background_opacity = 0.93;
          padding = 2;
          capsule = true;
          capsule_thickness = 0.65;
          capsule_padding = 10;
          widget_spacing = 10;
          margin_ends = 0;

          start = [
            "launcher"
            "active_window"
            "media"
          ];
          center = [ "workspaces" ];
          end = [
            "group:system-monitor"
            "battery"
            "volume"
            "clock"
            "tray"
            "control-center"
          ];

          capsule_group = [
            {
              id = "system-monitor";
              padding = 5;
              widget_spacing = 24;
              members = [
                "cpu"
                "temperature"
                "memory"
              ];
            }
          ];

          monitor = {
            "DP-1".enabled = true;
            "DP-3".enabled = true;
            "eDP-1".enabled = true;
          };
        };

        widget = {
          workspaces = {
            occupied_color = "tertiary";
            labels_only_when_occupied = false;
            scale = 1.45;
            pill_scale = 1.0;
          };
          media.album_art_only = true;

          cpu = {
            type = "sysmon";
            stat = "cpu_usage";
          };
          temperature = {
            type = "sysmon";
            stat = "cpu_temp";
          };
          memory = {
            type = "sysmon";
            stat = "ram_used";
          };

          clock.format = "{:%Y-%m-%d %H:%M:%S}";
        };

        dock = {
          enabled = true;
          icon_size = 60;
          active_monitor_only = false;
          monitors = [ "DP-1" ];
          auto_hide = true;
          reserve_space = false;
        };

        notification = {
          # Hokum owns org.freedesktop.Notifications; Noctalia keeps only its
          # own internal toasts.
          enable_daemon = false;
          monitors = [ "DP-1" ];
        };
      };
    };

    systemd.user.services.noctalia.Service.Environment = "TERMINAL=${lib.getExe pkgs.kitty}";

    wayland.windowManager.hyprland.settings = {
      layer_rule = [
        {
          name = "noctalia";
          match.namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$";
          no_anim = true;
          ignore_alpha = 0.5;
          blur = true;
          blur_popups = true;
        }
      ];
    };
  };
}
