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
    ];
    services.easyeffects = {
      enable = true;
      # package = pkgs.easyeffects;
    };
  };
}
