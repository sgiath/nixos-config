{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.remote = {
    enable = lib.mkEnableOption "CrazyEgg home manager";
  };

  config = lib.mkIf config.remote.enable {
    home.packages = with pkgs; [
      glab
    ];
  };
}
