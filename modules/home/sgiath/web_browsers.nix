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
      pkgs.lynx
      pkgs.ladybird
    ];

    programs = {
      chromium.enable = true;
      firefox.enable = true;

      # https://librewolf.net/docs/settings/
      librewolf.enable = true;

      qutebrowser = {
        enable = true;
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
      firefox.enable = false;
      librewolf.enable = false;
    };

    wayland.windowManager.hyprland.settings.windowrulev2 = [
      "workspace 2 silent, class:(chromium-browser)"
      "workspace 3 silent, class:(google-chrome)"
      "workspace 4 silent, class:(firefox)"
    ];
  };
}
