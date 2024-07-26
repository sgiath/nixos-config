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

    image = ./../wallpaper.jpg;
    imageScalingMode = "fit";

    base16Scheme = ./../theme.yaml;

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
