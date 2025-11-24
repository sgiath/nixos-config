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
          output = [
            "DP-1"
            "DP-3"
          ];
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
              format = {
                today = "<span color='#ff6699'><b><u>{}</u></b></span>";
              };
            };
          };
          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };
          tray.spacing = 10;
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
        }

        window#waybar {
          background-color: transparent;
          color: #eeeeee;
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
          color: #a7c080;
          background-color: #232323;
        }

        #workspaces button.urgent {
          color: #e67e8c;
        }

        #clock,
        #battery,
        #cpu,
        #memory,
        #disk,
        #temperature,
        #backlight,
        #network,
        #pulseaudio,
        #wireplumber,
        #custom-media,
        #tray,
        #mode,
        #idle_inhibitor,
        #scratchpad,
        #mpd {
          padding: 0 10px;
          margin-top: 3px;
          margin-bottom: 3px;
          border-radius: 8px;
          background-color: #232323;
        }

        #window,
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
          margin-right: 7px;
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
