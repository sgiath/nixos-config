{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.hyprland.enable {
    home.packages = with pkgs; [
      nemo-with-extensions
      nemo-fileroller
      webp-pixbuf-loader

      superfile
      exiftool
    ];
    wayland.windowManager.hyprland.settings.bind = [
      "$mod, E, exec, ${pkgs.kitty}/bin/kitty --class files -e ${pkgs.superfile}/bin/superfile"
    ];
  };
}
