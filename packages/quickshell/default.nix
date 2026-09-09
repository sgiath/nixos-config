{
  symlinkJoin,
  makeWrapper,
  quickshell,
  qt6,
}:
# Nixpkgs' quickshell only bundles the Qt modules it links against. The
# sgiath shell's video wallpaper needs QtMultimedia (QML module + ffmpeg
# backend plugin), so prefix the same variables wrapQtAppsHook uses instead
# of rebuilding quickshell from source and losing the binary cache.
#
# Home Manager's unit runs bin/quickshell; `qs` is the CLI alias.
symlinkJoin {
  name = "${quickshell.name}-multimedia";
  paths = [ quickshell ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    for bin in quickshell qs; do
      wrapProgram $out/bin/$bin \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${qt6.qtmultimedia}/lib/qt-6/qml \
        --prefix QT_PLUGIN_PATH : ${qt6.qtmultimedia}/lib/qt-6/plugins
    done
  '';
  passthru.qtmultimedia = qt6.qtmultimedia;
  inherit (quickshell) meta;
}
