{ config, lib, ... }:
{
  services.t3code = {
    enable = true;
    channel = "nightly";
    publicUrl = "https://t3-pallas.sgiath.dev";
  };

  sgiath.work = {
    crazyegg = {
      enable = true;
      # Ceres refreshes at :00 and Vesta at :30; each MFA code works once.
      awsRefreshMinute = 15;
    };
    remote.enable = true;
  };

  sgiath.desktop.wallpaper = ../../../modules/home/desktop/wallpapers/massier.jpg;

  # The shared rules bind workspaces to Ceres's outputs, which leaves none for
  # eDP-1 and starts the session on workspace 11. Same names, one screen.
  wayland.windowManager.hyprland.settings.workspace_rule = lib.mkForce (
    [
      {
        workspace = "s[true]";
        gaps_out = {
          top = 160;
          right = 300;
          bottom = 160;
          left = 300;
        };
      }
    ]
    ++
      lib.imap1
        (
          id: name:
          {
            workspace = toString id;
            monitor = "eDP-1";
            default = id == 1;
            persistent = true;
          }
          // lib.optionalAttrs (name != null) { default_name = name; }
          // lib.optionalAttrs (id == 10) {
            gaps_in = 0;
            gaps_out = 0;
            no_border = true;
          }
        )
        [
          "code"
          "p web"
          "c web"
          "r web"
          null
          null
          null
          "firefox"
          "email"
          "comm"
        ]
  );

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
