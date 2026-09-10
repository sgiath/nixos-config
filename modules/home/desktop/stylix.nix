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
  config = lib.mkMerge [
    # useGlobalPkgs: overlays come from the NixOS Stylix module.
    { stylix.overlays.enable = false; }

    (lib.mkIf config.sgiath.roles.desktop.enable {
      home.pointerCursor.enable = true;

      stylix = {
        enable = true;
        enableReleaseChecks = false;

        polarity = "dark";
        base16Scheme = ../../../themes/sgiath.yaml;

        cursor = {
          package = pkgs.volantes-cursors;
          name = "volantes_light_cursors";
          size = 32;
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
    })
  ];
}
