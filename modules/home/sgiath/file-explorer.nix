{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.hyprland.enable {
    home.packages = with pkgs; [
      superfile
      exiftool
    ];
    wayland.windowManager.hyprland.settings = {
      bind = [ "$mod, E, exec, ${pkgs.kitty}/bin/kitty --class files -e ${pkgs.superfile}/bin/superfile" ];
      windowrulev2 = [
        # "float, class:(files)"
        # "size 622 652, class:(files)"
        # "stayfocused, class:(files)"
      ];
    };
  };
}
