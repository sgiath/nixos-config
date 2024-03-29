{
  imports = [
    # default values
    ../../home-manager

    # CrazyEgg
    ../../work
  ];

  sgiath = {
    audio.enable = true;
    browser.enable = true;
    claws.enable = true;
    polybar.enable = true;
    rofi.enable = true;
    xmonad.enable = true;
  };

  stylix.fonts.sizes = {
    applications = 12;
    terminal = 14;
  };
}
