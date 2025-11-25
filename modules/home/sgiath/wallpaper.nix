{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  nasa_url = "https://eyes.nasa.gov/apps/solar-system/#/home?featured=false&detailPanel=false&logo=false&search=false&shareButton=false&menu=false&collapseSettingsOptions=true&hideFullScreenToggle=true&locked=true&hideExternalLinks=true";
  nasa_exec = pkgs.writeShellScriptBin "nasa" ''
    ${pkgs.ungoogled-chromium}/bin/chromium --kiosk --user-data-dir=/tmp/chrome-temp --incognito --no-first-run --ozone-platform=x11 --class=nasa "${nasa_url}"
  '';
in
{
  config = lib.mkIf config.programs.hyprland.enable {
    wayland.windowManager.hyprland = {
      plugins = [
        # pkgs.hyprlandPlugins.hyprwinwrap
        inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprwinwrap
      ];

      settings = {
        # exec-once = [
        #   "${nasa_exec}/bin/nasa"
        # ];

        bind = [
          "$mod, W, exec, ${nasa_exec}/bin/nasa"
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
            "${./wallpapers/triss1.jpg}"
            "${./wallpapers/triss2.jpg}"
            "${./wallpapers/waifu3.jpg}"
          ];
          wallpaper = [
            "DP-1,contain:${./wallpapers/waifu3.jpg}"
            "DP-3,contain:${./wallpapers/triss1.jpg}"
            "DP-2,contain:${./wallpapers/triss2.jpg}"
          ];
        };
      };
    };
  };
}
