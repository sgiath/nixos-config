{
  symlinkJoin,
  makeWrapper,
  quickshell,
  qt6,
}:
let
  # Upstream workaround `quickshell-hyprland-workspace-address`. Both `qs` and
  # `quickshell` come from this build.
  patched = quickshell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./hyprland-workspace-address.patch ];
  });
in
# Nixpkgs' quickshell only bundles the Qt modules it links against. The
# sgiath shell's video wallpaper needs QtMultimedia (QML module + ffmpeg
# backend plugin), so prefix the same variables wrapQtAppsHook uses instead
# of adding it to the build.
#
# Home Manager's unit runs bin/quickshell; `qs` is the CLI alias.
symlinkJoin {
  name = "${patched.name}-multimedia";
  paths = [ patched ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    for bin in quickshell qs; do
      wrapProgram $out/bin/$bin \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${qt6.qtmultimedia}/lib/qt-6/qml \
        --prefix QT_PLUGIN_PATH : ${qt6.qtmultimedia}/lib/qt-6/plugins
    done
  '';
  passthru.qtmultimedia = qt6.qtmultimedia;
  inherit (patched) meta;
}
