{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  unzip,
  callPackage,
  cloudflared,
  llm-agents,
}:

let
  # Pinned together with the CLI by ../t3code-nightly/update.sh.
  sources = lib.importJSON ../t3code-nightly/sources.json;
  arch =
    {
      x86_64-linux = "x86_64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-nightly-desktop";
  inherit (sources) version;

  # Unpacked and patched rather than run through appimageTools.wrapType2: its
  # bubblewrap user namespace maps /nix/store owners to nobody, and ssh then
  # rejects the Home Manager ~/.ssh/config, which breaks SSH environments.
  src = appimageTools.extract {
    inherit (finalAttrs) pname version;
    src = fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/T3-Code-${finalAttrs.version}-${arch}.AppImage";
      hash = sources.${stdenv.hostPlatform.system}.appimage;
    };
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Electron 44 runtime, libstdc++ for the prebuilt node modules, libsecret
  # for safeStorage and resources/browser-secret.
  buildInputs = [
    (lib.getLib stdenv.cc.cc)
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libsecret
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    (lib.getLib systemd)
  ];

  dontConfigure = true;
  dontBuild = true;

  # The extracted root keeps electron-builder's layout: the app resolves
  # resources/ next to the executable. usr/lib carries the AppImage's legacy
  # gtk2 tray libraries, which Electron does not load; the musl ffi-rs build
  # is never selected on glibc.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec $out/bin $out/share/applications
    cp -r . $out/libexec/t3code-desktop
    chmod -R u+w $out/libexec/t3code-desktop
    cd $out/libexec/t3code-desktop
    rm -r usr/lib AppRun .DirIcon t3code.png resources/app.asar.unpacked/node_modules/@yuuang/ffi-rs-linux-*-musl
    mv usr/share/icons $out/share/
    rm -r usr
    mv t3code.desktop $out/share/applications/

    # Same binary name as the stable t3code-desktop, so only one is installed.
    # T3 Connect otherwise downloads its pinned cloudflared relay client.
    # The downloaded Chrome headless shell does not inherit Electron's RPATH;
    # expose the same libraries to that browser through its environment.
    makeWrapper $out/libexec/t3code-desktop/t3code $out/bin/t3code-desktop \
      --prefix PATH : ${lib.makeBinPath llm-agents.t3code.providerPackages} \
      --prefix LD_LIBRARY_PATH : ${finalAttrs.passthru.libraryPath} \
      --set-default T3CODE_CLOUDFLARED_PATH ${lib.getExe cloudflared} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    substituteInPlace $out/share/applications/t3code.desktop \
      --replace-fail 'Exec=AppRun %U' 'Exec=t3code-desktop %U'

    runHook postInstall
  '';

  # ANGLE (bundled libGLESv2.so) dlopens libEGL.so.1 and safeStorage dlopens
  # libsecret-1.so.0 by soname; adding them to the main binary's DT_NEEDED
  # before patching puts them in the RPATH and in process scope for those
  # lookups. Without libsecret, saving a remote environment fails with
  # "Desktop secure storage is unavailable".
  dontAutoPatchelf = true;
  postFixup = ''
    patchelf --add-needed libGL.so.1 --add-needed libEGL.so.1 --add-needed libsecret-1.so.0 \
      $out/libexec/t3code-desktop/t3code
    autoPatchelf $out/libexec/t3code-desktop
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ unzip ];
  installCheckPhase = ''
    runHook preInstallCheck
    bash -n "$out/bin/t3code-desktop"
    grep -Fx 'Exec=t3code-desktop %U' "$out/share/applications/t3code.desktop" > /dev/null
    test -s "$out/share/icons/hicolor/512x512/apps/t3code.png"
    timeout 30 "$out/libexec/t3code-desktop/resources/resource-monitor/t3-resource-monitor" \
      < /dev/null > "$TMPDIR/resource-monitor.json"
    grep -F '"type":"hello"' "$TMPDIR/resource-monitor.json" > /dev/null
    source ${../t3code-nightly/check-libraries.sh}
    assertLinked $out/libexec/t3code-desktop/t3code libsecret-1.so.0 libEGL.so.1
    LD_LIBRARY_PATH=${finalAttrs.passthru.libraryPath} assertHeadlessShellResolved ${
      callPackage ../t3code-nightly/headless-shell.nix { }
    }
    runHook postInstallCheck
  '';

  passthru.libraryPath = lib.makeLibraryPath finalAttrs.buildInputs;

  meta = {
    description = "Desktop control surface for coding agents (nightly build)";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "t3code-desktop";
  };
})
