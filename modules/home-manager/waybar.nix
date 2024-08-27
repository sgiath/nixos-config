{
  config,
  lib,
  ...
}:

{
  options.sgiath.waybar = {
    enable = lib.mkEnableOption "waybar";
  };

  config = lib.mkIf config.sgiath.waybar.enable {
    programs.waybar = {
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
        };
        notebookBar = {
          height = 28;
          spacing = 12;
          output = [
            "eDP-1"
          ];
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
          memory = {
            format = "RAM: {used} GiB / {total} GiB";
          };
          cpu = {
            format = "CPU: {usage}% ({max_frequency}GHz)";
          };
          clock = {
            format = "{:%Y-%m-%d %H%M}";
          };
        };
      };
    };
  };
}
