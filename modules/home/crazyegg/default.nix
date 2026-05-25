{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./aws.nix ];

  options.crazyegg = {
    enable = lib.mkEnableOption "CrazyEgg home manager";
  };

  config = lib.mkIf config.crazyegg.enable {
    home.packages = with pkgs; [
      google-chrome
      insomnia
    ];
    wayland.windowManager.hyprland.settings.windowrule = [
      "match:class google-chrome, workspace 3 silent"
    ];
  };
}
