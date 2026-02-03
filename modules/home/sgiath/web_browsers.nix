{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  options.sgiath.web_browsers.enable = lib.mkEnableOption "web browsers";

  config = lib.mkIf config.sgiath.web_browsers.enable {
    home.packages = [
      pkgs.tor-browser
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.lynx
      pkgs.ladybird
    ];

    programs = {
      chromium.enable = true;
      firefox.enable = true;

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

    wayland.windowManager.hyprland.settings.windowrule = [
      "match:class firefox, workspace 4 silent"
    ];
  };
}
