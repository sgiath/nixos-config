{ config, pkgs, userSettings, ... }:

{
  imports = [
    # default values
    ../home.nix

    # audio
    ../../user/audio.nix

    # GUI apps
    ../../user/xmonad.nix
    ../../user/polybar.nix
    ../../user/rofi.nix
    ../../user/wezterm.nix
    ../../user/browser.nix
    ../../user/email_client.nix

    # Gaming
    ../../user/games.nix

    # CrazyEgg
    ../../work/aws.nix
  ];

  home.packages = [
    pkgs.nitrogen
    pkgs.killall
    pkgs.inotify-tools
  ];

  stylix = {
    fonts = {
      sizes = {
        applications = 10;
        desktop = 10;
        popups = 10;
        terminal = 10;
      };
    };
  };
}
