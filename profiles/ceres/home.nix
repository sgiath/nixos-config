{ pkgs, ... }:

{
  imports = [
    # default values
    ../home.nix

    # CrazyEgg
    ../../work/default.nix

    ../../user/audio.nix
    ../../user/gui.nix
    ../../user/games.nix
    ../../user/ollama.nix
  ];

  home.packages = [
    pkgs.nitrogen
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
