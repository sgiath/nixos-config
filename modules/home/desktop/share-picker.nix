{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.gtk) theme;

  # FIXME: 0.2.1's hyprland-rs cannot parse Hyprland 0.57 clients/monitors, so
  # only Region works. Drop once root nixpkgs selects 0.3.1; see
  # UPSTREAM-WORKAROUNDS.md#preview-share-picker-hyprland-057-ipc.
  unwrapped = pkgs.hyprland-preview-share-picker.overrideAttrs (
    final: prev: {
      version = "0.3.1";
      src = prev.src.override {
        tag = "v${final.version}";
        hash = "sha256-0yn7YG18SC6+h3vkJNDUda/esmBl6U1tu1LHIIXSknc=";
      };
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        inherit (final) pname version src;
        hash = "sha256-4nd0X6Ii6pbpQgzFCw2yXhl2+C5FyqDsHtbzKNpGW5o=";
      };
    }
  );

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

      # The portal's PATH has no slurp; this is the picker's default command
      # with an absolute path.
      "hyprland-preview-share-picker/config.yaml".text = lib.generators.toYAML { } {
        region.command = "${lib.getExe pkgs.slurp} -f '%o@%X,%Y,%W,%H'";
      };
    };
  };
}
