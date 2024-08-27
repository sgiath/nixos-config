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
    claws.enable = true;
    hyprland.enable = true;
    kitty.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 12;
    desktop = 12;
    popups = 12;
    terminal = 12;
  };
}
