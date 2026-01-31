{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gimp
    texliveMedium
    lmstudio
    # davinci-resolve-studio
  ];

  sgiath = {
    enable = true;
    games.enable = true;

    targets = {
      terminal = true;
      graphical = true;
    };
  };

  crazyegg.enable = true;

  programs.openclaw.enable = false;

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };
}
