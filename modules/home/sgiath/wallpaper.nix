{
  config,
  lib,
  pkgs,
  ...
}:
let
  nasa_url = "https://eyes.nasa.gov/apps/solar-system/#/home?featured=false&detailPanel=false&logo=false&search=false&shareButton=false&menu=false&collapseSettingsOptions=true&hideFullScreenToggle=true&locked=true&hideExternalLinks=true";
  nasa_exec = pkgs.writeShellScriptBin "nasa" ''
    ${lib.getExe pkgs.ungoogled-chromium} --kiosk --user-data-dir=/tmp/chrome-temp --incognito --no-first-run --ozone-platform=x11 --class=nasa "${nasa_url}"
  '';
in
{
  config = lib.mkIf config.programs.hyprland.enable {
    wayland.windowManager.hyprland = {
      plugins = [
        # pkgs.hyprlandPlugins.hyprwinwrap
        # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprwinwrap
      ];

      settings = {
        # exec-once = [
        #   "${lib.getExe nasa_exec}"
        # ];

        bind = [
          "$mod, W, exec, ${lib.getExe nasa_exec}"
        ];

        plugin.hyprwinwrap = {
          class = "nasa";
          pos_x = 0;
          pos_y = 10;
        };

        windowrule = [
          "match:class nasa, fullscreen_state 0 0, workspace special:nasa silent"
        ];
      };
    };

    services = {
      hyprpaper = {
        enable = true;
        settings = lib.mkForce {
          preload = [
            "${./wallpapers/marry.jpg}"
            "${./wallpapers/triss1.jpg}"
            "${./wallpapers/solar-system.jpg}"
          ];
          wallpaper = [
            {
              monitor = "DP-1";
              fit_mode = "contain";
              path = "${./wallpapers/marry.jpg}";
            }
            {
              monitor = "DP-3";
              fit_mode = "contain";
              path = "${./wallpapers/triss1.jpg}";
            }
            {
              monitor = "DP-2";
              fit_mode = "contain";
              path = "${./wallpapers/solar-system.jpg}";
            }
          ];
        };
      };
    };
  };
}
