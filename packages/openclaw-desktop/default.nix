{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  webkitgtk_4_1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openclaw-desktop";
  version = "2026.8.2";

  src = fetchurl {
    url = "https://github.com/openclaw/openclaw/releases/download/v${finalAttrs.version}/OpenClaw-${finalAttrs.version}-amd64.deb";
    hash = "sha256-YCGsOLOY/DtME2T3L7g6XYni1sIO1rvm087tDN2+qoU=";
  };

  sourceRoot = "root";

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    cairo
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libsoup_3
    webkitgtk_4_1
    (lib.getLib stdenv.cc.cc)
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
  ];

  # Tauri dlopens the tray library at runtime; it is not in DT_NEEDED.
  runtimeDependencies = [ libayatana-appindicator ];

  dontConfigure = true;
  dontBuild = true;

  # Keep the Debian layout: the binary resolves its bundled install-cli.sh
  # through Tauri's resource dir at <exe>/../lib/OpenClaw.
  installPhase = ''
    runHook preInstall

    mkdir -p $out
    mv usr/bin usr/lib usr/share $out/

    runHook postInstall
  '';

  # Deliberately no update-desktop-database on PATH: the deep-link plugin would
  # register an openclaw:// handler pointing at the unwrapped ELF (current_exe),
  # bypassing the GApps wrapper on cold start. It logs "Deep-link registration
  # unavailable" and the packaged OpenClaw.desktop (MimeType=x-scheme-handler/
  # openclaw, Exec through the wrapper) handles the scheme instead.

  # FIXME: the remote-gateway SSH tunnel spawns /usr/bin/ssh, which does not
  # exist on NixOS. Rust string literals are inline and length-fixed, so it
  # cannot be safely patched; revisit if upstream reads ssh from PATH or the
  # remote mode is needed.

  meta = {
    description = "OpenClaw Linux companion: installs the CLI, manages the local Gateway and hosts the Control UI";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "openclaw-desktop";
  };
})
