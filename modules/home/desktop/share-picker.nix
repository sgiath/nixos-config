{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.gtk) theme;

  # settings.ini names the light variant of the Stylix theme. The theme travels
  # with the wrapper because the picker runs in the portal's environment.
  picker = pkgs.symlinkJoin {
    inherit (pkgs.hyprland-preview-share-picker) pname version meta;
    paths = [ pkgs.hyprland-preview-share-picker ];
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

      # The portal's PATH has no slurp; this is the picker's default command
      # with an absolute path.
      "hyprland-preview-share-picker/config.yaml".text = lib.generators.toYAML { } {
        region.command = "${lib.getExe pkgs.slurp} -f '%o@%X,%Y,%W,%H'";
      };
    };
  };
}
