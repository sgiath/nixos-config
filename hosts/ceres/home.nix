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
    claws.enable = true;
    games.enable = true;
    ollama.enable = false;
    hyprland.enable = true;
    kitty.enable = true;
    davinci.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
