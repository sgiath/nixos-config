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
    ];

    programs = {
      chromium.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
        profiles.default.path = "l5hqlmby.default";
      };

      # https://librewolf.net/docs/settings/
      librewolf.enable = false;

      qutebrowser = {
        enable = false;
        searchEngines = {
          DEFAULT = "https://search.sgiath.dev/search?q={}";
        };
        quickmarks = {
          nixpkgs = "https://github.com/NixOS/nixpkgs";
        };
        # https://qutebrowser.org/doc/help/settings.html
        settings = {
          auto_save.session = true;
          colors.webpage.darkmode.enabled = true;
        };
      };
    };

    stylix.targets = {
      firefox.profileNames = [ "default" ];
    };
  };
}
