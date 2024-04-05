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

    # Wayland
    # hyprland.enable = true;
    # kitty.enable = true;

    # X11
    polybar.enable = true;
    xmonad.enable = true;
    rofi.enable = true;
    wezterm.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
