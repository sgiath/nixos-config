{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.programs.audio.enable {
    home.packages = with pkgs; [
      qpwgraph
      pavucontrol
      alsa-scarlett-gui
    ];
  };
}
