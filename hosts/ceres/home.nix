{ pkgs, ... }:

{
  imports = [
    ../../home-manager

    # CrazyEgg
    ../../work
  ];

  sgiath = {
    audio.enable = true;
    browser.enable = true;
    claws.enable = true;
    games.enable = true;
    ollama.enable = true;
    polybar.enable = true;
    rofi.enable = true;
    xmonad.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
