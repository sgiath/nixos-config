{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.work.crazyegg.enable {
    home.packages = lib.optionals config.sgiath.roles.desktop.enable [
      pkgs.google-chrome
    ];
  };
}
