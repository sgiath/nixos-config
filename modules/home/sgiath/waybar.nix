{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf (config.programs.hyprland.enable && config.programs.waybar.enable) {
    stylix.targets.waybar.enable = false;
    programs.waybar = {
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 36;
          spacing = 16;
          output = [ "DP-1" ];
          modules-left = [
            "hyprland/workspaces"
          ];
          modules-center = [
            "hyprland/window"
          ];
          modules-right = [
            "network"
            "network#2"
            "cpu"
            "memory"
            "clock"
            "custom/voxtype"
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
          };
          tray.spacing = 10;
        };
        secondBar = {
          layer = "top";
          position = "top";
          height = 36;
          spacing = 16;
          output = [
            "DP-3"
          ];
          modules-left = [
            "hyprland/workspaces"
          ];
          modules-center = [
            "hyprland/window"
          ];
          modules-right = [
            "clock"
          ];

          clock = {
            format = "{:%Y-%m-%d %H%M}";
            interval = 1;
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
      style = ''
        * {
          font-family: 'RobotoMono Nerd Font Mono', sans-serif;
          font-size: 16px;
          color: #eeeeee;
        }

        window#waybar {
          background-color: transparent;
          border: none;
        }

        button {
          /* Use box-shadow instead of border so the text isn't offset */
          box-shadow: inset 0 -1px transparent;

          border: none;
          border-radius: 8px;
        }

        /* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
        button:hover {
          background: inherit;
          box-shadow: inset 0 -1px #a7c080;
        }

        #workspaces button {
          background-color: transparent;
        }

        #workspaces button.active {
          background-color: #232323;
        }

        #workspaces button.urgent {
          color: #e67e8c;
        }

        #clock,
        #battery,
        #cpu,
        #memory,
        #network,
        #window,
        #tray {
          padding-left: 8px;
          padding-right: 8px;
          margin-top: 3px;
          margin-bottom: 3px;
          margin-left: 8px;
          margin-right: 8px;
          border-radius: 8px;
          background-color: #232323;
        }

        #workspaces {
          margin: 0 8px;
        }

        /* If workspaces is the leftmost module, omit left margin */
        .modules-left > widget:first-child > #workspaces {
          margin-left: 0;
        }

        /* If workspaces is the rightmost module, omit right margin */
        .modules-right > widget:last-child > #workspaces {
          margin-right: 0;
        }

        #clock {
          font-weight: bold;
        }

        #battery {
          background-color: #d699b6;
          color: #2d353b;
        }

        #battery.charging, #battery.plugged {
          color: #2d353b;
          background-color: #83c092;
        }

        @keyframes blink {
          to {
            background-color: #ffffff;
            color: #000000;
          }
        }

        #battery.critical:not(.charging) {
          background-color: #f53c3c;
          color: #ffffff;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
        }

        #network.disconnected {
          background-color: #e67e80;
          color: #232a2e;
        }

        #tray > .passive {
          -gtk-icon-effect: dim;
        }

        #tray > .needs-attention {
          -gtk-icon-effect: highlight;
          background-color: #eb4d4b;
        }
      '';
    };
  };
}
