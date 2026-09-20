{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  tmux,
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
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "agent-orchestrator";
  version = "0.13.0";

  src = fetchurl {
    url = "https://github.com/Untrivial-ai/agent-orchestrator/releases/download/v${finalAttrs.version}/agent-orchestrator-linux-x64.deb";
    hash = "sha256-XMem1ooY1lGwVmQxxM4pOiQc6Ek+dvcPwkXxW3lFHhQ=";
  };

  sourceRoot = "root";

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # Electron 33 runtime plus libstdc++ for the bundled Node (ACP runtime) and
  # the better-sqlite3 native module, which is compiled against this exact
  # Electron ABI; swapping in nixpkgs electron would break it.
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
  # The tmux shim below must keep #!/bin/sh: it is copied out of the store.
  dontPatchShebangs = true;

  # Keep the electron-builder layout: main.js resolves the Go daemon, tmux,
  # agent-browser and the ACP Node runtime relative to process.resourcesPath
  # (<exe dir>/resources), and the daemon finds tmux relative to its own path.
  #
  # The bundled tmux is a static glibc build that looks for locale data under
  # /usr/lib/locale and aborts with "invalid LC_ALL" on NixOS. main.js copies
  # resources/tmux/bin/tmux once into ~/.ao/runtime/tmux/<version>-linux-x64/
  # (AppImage mounts vanish while the daemon outlives Electron) and ignores an
  # inherited AO_TMUX_BINARY, so ship a shim there instead: the copy keeps
  # pointing at nixpkgs tmux and falls back to PATH if that store path is
  # garbage-collected after a nixpkgs bump that did not change the AO version.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mv usr/lib usr/share $out/
    rm -r $out/share/lintian

    cat > $out/lib/agent-orchestrator/resources/tmux/bin/tmux <<EOF
    #!/bin/sh
    [ -x ${lib.getExe tmux} ] && exec ${lib.getExe tmux} "\$@"
    exec tmux "\$@"
    EOF
    chmod +x $out/lib/agent-orchestrator/resources/tmux/bin/tmux

    makeWrapper $out/lib/agent-orchestrator/agent-orchestrator $out/bin/agent-orchestrator \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    # The deb never installs the CLI; AO only prepends resources/daemon to the
    # PATH of agents it spawns. Expose it for the user's own shell too.
    ln -s ../lib/agent-orchestrator/resources/daemon/ao $out/bin/ao

    runHook postInstall
  '';

  # patchelf (0.15 and 0.18) corrupts the Go daemon when it adds an rpath: it
  # relocates .dynamic into the read-only text segment and ao SIGSEGVs on
  # start. ao only needs libc, so it gets an interpreter and nothing else.
  #
  # ANGLE (bundled libGLESv2.so) dlopens libEGL.so.1 by soname; adding it to
  # the main binary's DT_NEEDED puts it in process scope for that lookup.
  dontAutoPatchelf = true;
  postFixup = ''
    daemon=$out/lib/agent-orchestrator/resources/daemon/ao
    mv $daemon $TMPDIR/ao
    patchelf --add-needed libGL.so.1 --add-needed libEGL.so.1 \
      $out/lib/agent-orchestrator/agent-orchestrator
    autoPatchelf $out/lib/agent-orchestrator
    mv $TMPDIR/ao $daemon
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $daemon
  '';

  meta = {
    description = "Plan, run, and supervise teams of coding agents from one desktop workspace";
    homepage = "https://github.com/Untrivial-ai/agent-orchestrator";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "agent-orchestrator";
  };
})
