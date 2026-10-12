{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hyprland/color.nix
    ./hyprland/general.nix
    ./hyprland/keybindings.nix
    ./hyprland/layout.nix
    ./hyprland/looks.nix
    ./hyprland/monitors.nix
    ./hyprland/rules.nix
    ./hyprland/screenshot.nix
  ];

  config = lib.mkIf config.sgiath.roles.desktop.enable {
    # home.packages = [ ];

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      xwayland.enable = true;
      package = null;
      portalPackage = null;

      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [ "--all" ];
      };

      settings = {
        config.group.groupbar.font_size = 14;

        workspace_rule = [
          # Scratchpads sit inset over their dimmed workspace, like a modal, leaving
          # about a quarter of each monitor axis visible. Later matching rules win.
          # Fallback, sized for eDP-1 (2560x1600).
          {
            workspace = "s[true]";
            gaps_out = {
              top = 160;
              right = 300;
              bottom = 160;
              left = 300;
            };
          }
          # 5120x1440; the Quickshell rails reserve another 96 px on each side.
          {
            workspace = "s[true] m[DP-1]";
            gaps_out = {
              top = 160;
              right = 500;
              bottom = 160;
              left = 500;
            };
          }
          # 3440x1440
          {
            workspace = "s[true] m[DP-3]";
            gaps_out = {
              top = 160;
              right = 400;
              bottom = 160;
              left = 400;
            };
          }
          # Portrait, 1440x2560 logical
          {
            workspace = "s[true] m[DP-2]";
            gaps_out = {
              top = 300;
              right = 160;
              bottom = 300;
              left = 160;
            };
          }
          # DP-1: code (1-2) and universal (6-8); DP-3: browsers (3-5) and email (9); DP-2: comm (10)
          {
            workspace = "1";
            monitor = "DP-1";
            default = true;
            persistent = true;
            default_name = "code";
          }
          {
            workspace = "2";
            monitor = "DP-3";
            persistent = true;
            default_name = "p web";
          }
          {
            workspace = "3";
            monitor = "DP-3";
            default = true;
            persistent = true;
            default_name = "c web";
          }
          {
            workspace = "4";
            monitor = "DP-3";
            persistent = true;
            default_name = "r web";
          }
          {
            workspace = "5";
            monitor = "DP-1";
            persistent = true;
          }
          {
            workspace = "6";
            monitor = "DP-1";
            persistent = true;
          }
          {
            workspace = "7";
            monitor = "DP-1";
            persistent = true;
          }
          {
            workspace = "8";
            monitor = "DP-1";
            persistent = true;
            default_name = "firefox";
          }
          {
            workspace = "9";
            monitor = "DP-3";
            persistent = true;
            default_name = "email";
          }
          {
            workspace = "10";
            monitor = "DP-2";
            default = true;
            gaps_in = 0;
            gaps_out = 0;
            no_border = true;
            persistent = true;
            default_name = "comm";
          }
        ];
      };
    };

    gtk = {
      iconTheme = {
        package = pkgs.tela-icon-theme;
        name = "Tela-dark";
      };
    };

    services = {
      hyprpolkitagent.enable = true;
    };
  };
}
