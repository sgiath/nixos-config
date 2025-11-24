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
          spacing = 0;
          output = [
            "DP-1"
            "DP-3"
          ];
          modules-left = [
            "custom/logo"
            "hyprland/workspaces"
          ];
          modules-right = [
            "custom/kernel"
            "custom/free-disk"
            "network"
            "network#2"
            "cpu"
            "memory"
            "clock"
            "wireplumber"
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
          clock.format = "{:%Y-%m-%d %H%M}";
          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };
          "custom/kernel" = {
            format = "{}";
            interval = 3600;
            exec = "uname -r";
          };
          "custom/logo" = {
            format = "";
          };
          "custom/free-disk" = {
            format = "󰆼 Disk: {}% used";
            interval = 3600;
            exec = "df -json | jq '.[] | select(.mount_point == \"/\")' | jq '(.free / .total * 1000 | round / 10.0)'";
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
