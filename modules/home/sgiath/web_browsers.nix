{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.sgiath.web_browsers.enable = lib.mkEnableOption "web browsers";

  config = lib.mkIf config.sgiath.web_browsers.enable {
    home.packages = [
      pkgs.tor-browser
      pkgs.zen-browser
    ];

    programs.chromium.enable = true;

    # Firefox
    programs.firefox.enable = true;
    stylix.targets.firefox.enable = false;
  };
}
