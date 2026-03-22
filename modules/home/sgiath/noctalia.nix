{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  config = lib.mkIf config.programs.hyprland.enable {
    programs.noctalia-shell = {
      enable = true;
      # settings = { };
    };
    wayland.windowManager.hyprland.settings = {
      layerrule = {
        name = "noctalia";
        "match:namespace" = "noctalia-background-.*$";
        ignore_alpha = 0.5;
        blur = true;
        blur_popups = true;
      };
    };
  };
}
