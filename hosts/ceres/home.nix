{ pkgs, ... }:

{
  imports = [
    ../../home-manager

    # CrazyEgg
    ../../work
  ];

  home.packages = [
    pkgs.betaflight-configurator
    pkgs.bisq-desktop
    pkgs.trezor-suite
    pkgs.trezor-udev-rules
  ];

  sgiath = {
    audio.enable = true;
    browser.enable = true;
    davinci.enable = true;
    email_client.enable = true;
    games.enable = true;
    hyprland.enable = true;
    kitty.enable = true;

    waybar.enable = true;

    ollama.enable = false;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
