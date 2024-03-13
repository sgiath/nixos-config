{ config, pkgs, stylix, userSettings, ... }:

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

    # CrazyEgg
    ../../work/aws.nix
    ../../work/nginx.nix
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
