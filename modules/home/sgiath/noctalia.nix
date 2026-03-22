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
  };
}
