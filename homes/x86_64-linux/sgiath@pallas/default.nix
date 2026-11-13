{ config, lib, ... }:
{
  services.t3code.enable = true;

  stylix.fonts.sizes = {
    applications = 12;
    desktop = 12;
    popups = 12;
    terminal = 12;
  };

  # The sgiath desktop shell has no network panel.
  xdg.desktopEntries = {
    wifi = {
      name = "Wi-Fi";
      exec = "${lib.getExe config.programs.kitty.package} -e nmtui-connect";
      icon = "network-wireless";
      categories = [ "Network" ];
    };

    # A fresh profile without extensions or saved HTTPS upgrades, opening a
    # plain-HTTP page the captive portal can redirect.
    hotel-login = {
      name = "Hotel login";
      exec = lib.concatStringsSep " " [
        (lib.getExe config.programs.chromium.finalPackage)
        "--user-data-dir=${config.xdg.dataHome}/captive-portal-browser"
        "http://neverssl.com"
      ];
      icon = "web-browser";
      categories = [ "Network" ];
    };
  };
}
