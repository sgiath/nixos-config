{ pkgs, ... }:

{
  imports = [
    # default values
    ../../home-manager

    # CrazyEgg
    ../../work
  ];

  home.packages = [
    pkgs.lshw
  ];

  sgiath = {
    audio.enable = true;
    browser.enable = true;
    davinci.enable = false;
    email_client.enable = true;
    games.enable = false;
    hyprland.enable = true;
    kitty.enable = true;

    waybar.enable = true;

  };

  stylix.fonts.sizes = {
    applications = 12;
    desktop = 12;
    popups = 12;
    terminal = 12;
  };
}
