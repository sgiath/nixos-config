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
      bind = [ "$mod, V, exec, ${lib.getExe pkgs.kitty} --class clipse -e ${lib.getExe pkgs.clipse}" ];
      windowrule = [
        "match:class clipse, float on, size 622 652, stay_focused on"
      ];
    };
  };
}
