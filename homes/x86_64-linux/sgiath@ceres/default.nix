{ pkgs, ... }:
{
  home.packages = with pkgs; [
    texliveMedium
    # lmstudio
    # davinci-resolve-studio
    whisper-cpp-vulkan
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

  stylix.fonts.sizes = {
    applications = 10;
    desktop = 10;
    popups = 10;
    terminal = 10;
  };

  # services = {
  #   niamh.enable = false;
  # };
}
