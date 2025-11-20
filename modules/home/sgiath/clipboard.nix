{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.hyprland.enable {
    services.clipse.enable = true;
    home.packages = with pkgs; [
      wl-clipboard
      wl-clipboard-x11
    ];
    wayland.windowManager.hyprland.settings = {
      bind = [ "$mod, V, exec, ${pkgs.kitty}/bin/kitty --class clipse -e ${pkgs.clipse}/bin/clipse" ];
      windowrule = [
        "match:class clipse, float on, size 622 652, stayfocused"
      ];
    };
  };
}
