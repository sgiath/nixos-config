{
  config,
  lib,
  pkgs,
  ...
}:
let
  font = {
    package = pkgs.nerd-fonts.roboto-mono;
    name = "RobotoMono Nerd Font Mono";
  };
in
{
  config = lib.mkIf config.sgiath.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;

      polarity = "dark";
      base16Scheme = ./theme.yaml;

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
  };
}
