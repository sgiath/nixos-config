{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../home.nix

    # desktop has GUI
    (./. + "../../../user/${userSettings.wm}/default.nix")
    ../../user/polybar.nix
    ../../user/wezterm.nix
    ../../user/browser.nix
  ];

  stylix = {
    polarity = "dark";

    image = ./wallpaper.jpg;
    base16Scheme = ./theme.yaml;

    fonts = {
      monospace = {
        package = (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; });
        name = "RobotoMono Nerd Font Mono";
      };
      serif = {
        package = (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; });
        name = "RobotoMono Nerd Font Mono";
      };
      sansSerif = {
        package = (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; });
        name = "RobotoMono Nerd Font Mono";
      };
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-emoji-blob-bin;
      };

      sizes = {
        applications = 10;
        terminal = 10;
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
      };
    };

    zathura = {
      enable = true;
    };
  };
}
