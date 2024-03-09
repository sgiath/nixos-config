{ config, pkgs, stylix, userSettings, ... }:

{
  imports = [
    # default values
    ../home.nix

    # audio
    ../../user/audio.nix

    # GUI apps
    ../../user/xmonad/default.nix
    ../../user/polybar/polybar.nix
    ../../user/rofi.nix
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
}
