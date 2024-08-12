{ inputs, pkgs, ... }:
let
  font = {
    package = (pkgs.nerdfonts.override { fonts = [ "RobotoMono" ]; });
    name = "RobotoMono Nerd Font Mono";
  };
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;

    polarity = "dark";

    image = ./../wallpapers/girl.png;
    imageScalingMode = "fit";

    base16Scheme = ./../theme.yaml;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    fonts = {
      monospace = font;
      serif = font;
      sansSerif = font;
      emoji = {
        name = "Noto Color Emoji";
        package = pkgs.noto-fonts-emoji-blob-bin;
      };
    };
  };
}
