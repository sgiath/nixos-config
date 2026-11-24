{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf config.sgiath.programs.browsers.enable {
    home.packages = [
      pkgs.tor-browser
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    programs = {
      chromium.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
        profiles.default.path = "l5hqlmby.default";
      };
    };

    stylix.targets = {
      firefox.profileNames = [ "default" ];
    };
  };
}
