{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.audio = {
    enable = lib.mkEnableOption "audio";
  };

  config = lib.mkIf config.sgiath.audio.enable {
    home.packages = with pkgs; [
      qpwgraph
      pavucontrol
      alsa-scarlett-gui
    ];
    services.easyeffects = {
      enable = false;
    };
  };
}
