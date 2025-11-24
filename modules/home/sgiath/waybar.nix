{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (config.programs.hyprland.enable && config.programs.waybar.enable) {
    # stylix.targets.waybar = {
    #   enableLeftBackColors = true;
    #   enableRightBackColors = true;
    # };

    programs.waybar = {
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 36;
          spacing = 16;
          output = [
            "DP-1"
            "DP-3"
          ];
          modules-left = [
            "hyprland/workspaces"
          ];
          modules-right = [
            "network"
            "network#2"
            "cpu"
            "memory"
            "clock"
            "tray"
          ];

          network = {
            interface = "enp57s0";
            format = "{ipaddr}: {bandwidthUpBytes} / {bandwidthDownBytes}";
          };
          "network#2" = {
            interface = "enp59s0";
            format = "{ipaddr}: {bandwidthUpBytes} / {bandwidthDownBytes}";
          };
          memory.format = "RAM: {used} GiB / {total} GiB";
          cpu.format = "CPU: {usage}% ({max_frequency}GHz)";
          clock = {
            format = "{:%Y-%m-%d %H%M}";
            interval = 1;
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "year";
              mode-mon-col = 3;
              weeks-pos = "right";
              on-scroll = 1;
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                days = "<span color='#ecc6d9'><b>{}</b></span>";
                weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b><u>{}</u></b></span>";
              };
            };
          };
          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };
        };
        notebookBar = {
          height = 28;
          spacing = 12;
          output = [ "eDP-1" ];
          modules-left = [ "hyprland/workspaces" ];
          modules-right = [
            "network"
            "memory"
            "cpu"
            "clock"
            "tray"
          ];

          network = {
            interface = "wlp3s0";
            format = "{ipaddr}: {bandwidthUpBytes} / {bandwidthDownBytes}";
          };
          memory.format = "RAM: {used} GiB / {total} GiB";
          cpu.format = "CPU: {usage}% ({max_frequency}GHz)";
          clock.format = "{:%Y-%m-%d %H%M}";
        };
      };
    };
  };
}
