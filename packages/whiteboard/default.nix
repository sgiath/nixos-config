{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  python3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  git,
  glib,
  gtk3,
  krb5,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxkbfile,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  xdg-utils,
  zlib,
}:

let
  runtimePath = lib.makeBinPath [
    git
    xdg-utils
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "whiteboard";
  version = "0.2.4";

  src = fetchurl {
    url = "https://github.com/devdotfast/whiteboard/releases/download/v${finalAttrs.version}/whiteboard_${finalAttrs.version}-1_amd64.deb";
    hash = "sha256-2dDNCwm8zoVme0AJebauM5swpe3lwr775Mmh6NN/Dpc=";
  };

  sourceRoot = "root";

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxkbfile
    libxrandr
    nspr
    nss
    pango
    (lib.getLib systemd)
    (lib.getLib stdenv.cc.cc)
    zlib
  ];

  # Chromium and the Code - OSS services dlopen these; they are not DT_NEEDED.
  runtimeDependencies = [
    krb5
    libnotify
    libsecret
    (lib.getLib systemd)
    wayland
  ];

  # The bundled ANGLE (libGLESv2.so) dlopens libEGL.so.1/libGL.so.1 through its
  # own RUNPATH, and runtimeDependencies only reach executables.
  appendRunpaths = [ "${lib.getLib libglvnd}/lib" ];

  dontConfigure = true;
  dontBuild = true;

  # The canvas uses both Code OSS theme colors and its own CSS palette.
  postPatch = ''
    ${lib.getExe python3} ${./theme.py} usr/share/whiteboard/resources/app
  '';

  # Electron resolves resources/ next to its executable, so the Debian
  # /usr/share/whiteboard tree is kept intact. The deb's legacy `review`
  # aliases, /usr/share/review compat links and AppArmor profile are dropped;
  # the app and its agent instructions only use `whiteboard`.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    mv usr/share/whiteboard usr/share/applications usr/share/icons usr/share/metainfo $out/share/

    # Not setuid in the store; Chromium uses the user-namespace sandbox instead.
    rm $out/share/whiteboard/chrome-sandbox

    # The CLI launches the desktop through its own Electron binary
    # (process.execPath), not through whiteboard-desktop, so both wrappers
    # carry the same environment for the desktop to inherit.
    makeWrapper $out/share/whiteboard/whiteboard $out/bin/whiteboard-desktop \
      --unset ELECTRON_RUN_AS_NODE \
      --unset VSCODE_DEV \
      --unset VSCODE_CLI \
      --suffix PATH : ${runtimePath}

    makeWrapper $out/share/whiteboard/whiteboard $out/bin/whiteboard \
      --set ELECTRON_RUN_AS_NODE 1 \
      --suffix PATH : ${runtimePath} \
      --add-flags $out/share/whiteboard/resources/app/review-runtime/dist/cli.js

    substituteInPlace $out/share/applications/*.desktop \
      --replace-fail /usr/bin/whiteboard-desktop $out/bin/whiteboard-desktop

    runHook postInstall
  '';

  meta = {
    description = "Open-source canvas where humans and coding agents review and design software together";
    homepage = "https://github.com/devdotfast/whiteboard";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "whiteboard-desktop";
  };
})
