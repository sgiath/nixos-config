{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../home.nix

    # desktop has GUI
    (./. + "../../../user/${userSettings.wm}/default.nix")
    ../../user/polybar/polybar.nix
    ../../user/wezterm.nix
    ../../user/browser.nix
    ../../user/email_client.nix
  ];

  stylix = {
    fonts = {
      sizes = {
        applications = 12;
        terminal = 14;
      };
    };
  };

  services = {
    # Desktop has audio
    easyeffects = {
      enable = true;
    };
  };

  programs = {
    rofi = {
      enable = true;
      terminal = "${pkgs.wezterm}/bin/wezterm";
      extraConfig = {
        modi = "window,ssh,drun,filebrowser";
        drun-show-actions = true;
        display-drun = "";
      };
    };

    zathura = {
      enable = true;
    };
  };
}
