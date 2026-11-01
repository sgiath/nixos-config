{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.gtk) theme;
  unwrapped = pkgs.hyprland-preview-share-picker;

  # settings.ini names the light variant of the Stylix theme. The theme travels
  # with the wrapper because the picker runs in the portal's environment.
  picker = pkgs.symlinkJoin {
    inherit (unwrapped) pname version meta;
    paths = [ unwrapped ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hyprland-preview-share-picker \
        --set GTK_THEME ${theme.name}:dark \
        --prefix XDG_DATA_DIRS : ${theme.package}/share
    '';
  };
in
{
  config = lib.mkIf config.sgiath.roles.desktop.enable {
    home.packages = [ picker ];

    xdg.configFile = {
      "hypr/xdph.conf".text = ''
        screencopy {
          custom_picker_binary = ${lib.getExe picker}
        }
      '';

      # The portal's PATH has no slurp, and 0.2.1's default command prints global
      # coordinates; see UPSTREAM-WORKAROUNDS.md#preview-share-picker-region-coordinates.
      "hyprland-preview-share-picker/config.yaml".text = lib.generators.toYAML { } {
        region.command = "${lib.getExe pkgs.slurp} -f '%o@%X,%Y,%W,%H'";
      };
    };
  };
}
