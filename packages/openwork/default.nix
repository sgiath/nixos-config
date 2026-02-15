{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  glib,
  gdk-pixbuf,
  cairo,
  pango,
  libsoup_3,
  openssl,
}:

stdenv.mkDerivation rec {
  pname = "openwork";
  version = "0.11.72";

  src = fetchurl {
    url = "https://github.com/different-ai/openwork/releases/download/v${version}/openwork-desktop-linux-amd64.deb";
    hash = "sha256-RaEAExWZyYvG00TLJtB1b0BbBOkQ7qFLetdJL1tw2lA=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    gdk-pixbuf
    cairo
    pango
    libsoup_3
    openssl
  ];

  unpackPhase = ''
    ar x $src
    tar -xf data.tar.gz
  '';

  installPhase = ''
    runHook preInstall

    # Install binaries
    install -Dm755 usr/bin/openwork $out/bin/openwork
    install -Dm755 usr/bin/openwork-server $out/bin/openwork-server
    install -Dm755 usr/bin/owpenbot $out/bin/owpenbot

    # Install desktop file
    install -Dm644 usr/share/applications/OpenWork.desktop $out/share/applications/openwork.desktop

    # Install icons
    for size in 32x32 128x128 "256x256@2"; do
      install -Dm644 usr/share/icons/hicolor/$size/apps/openwork.png \
        $out/share/icons/hicolor/$size/apps/openwork.png
    done

    runHook postInstall
  '';

  # wrapGAppsHook3 handles GTK environment setup
  dontWrapGApps = false;

  meta = with lib; {
    description = "Open-source alternative to Claude Cowork, powered by opencode";
    homepage = "https://github.com/different-ai/openwork";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "openwork";
  };
}
