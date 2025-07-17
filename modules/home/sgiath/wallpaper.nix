{
  config,
  lib,
  pkgs,
  ...
}:
let 
  nasa_url = "https://eyes.nasa.gov/apps/solar-system/#/home?featured=false&detailPanel=false&logo=false&search=false&shareButton=false&menu=false&collapseSettingsOptions=true&hideFullScreenToggle=true&locked=true&hideExternalLinks=true";
  nasa_exec = pkgs.writeShellScriptBin "nasa" ''
    ${pkgs.ungoogled-chromium}/bin/chromium --kiosk --user-data-dir=/tmp/chrome-temp --incognito --no-first-run --ozone-platform=x11 --class=nasa "${nasa_url}"
  '';
in {
  config = lib.mkIf config.programs.hyprland.enable {
    wayland.windowManager.hyprland = {
      plugins = [
        pkgs.hyprlandPlugins.hyprwinwrap
      ];

      settings = {
        exec-once = [
          "${nasa_exec}/bin/nasa"
        ];

        bind = [
          "$mod, W, exec, ${nasa_exec}/bin/nasa"
        ];

        plugin.hyprwinwrap.class = "nasa";
        
        windowrulev2 = [
          "fullscreenstate 0 0, class:(nasa)"
          "workspace special:nasa silent, class:(nasa)"
          "noinitialfocus, class:(nasa)"
          "move 100 0, class:(nasa)"
        ];
      };
    };

    services = {
      hyprpaper = {
        enable = true;
        settings = lib.mkForce {
          preload = [ "${./wallpapers/transhumanism.png}" ];
          wallpaper = [
            "DP-1,contain:${./wallpapers/transhumanism.png}"
            "DP-3,contain:${./wallpapers/transhumanism.png}"
            "DP-2,contain:${./wallpapers/transhumanism.png}"
          ];
        };
      };
    };
  };
}
