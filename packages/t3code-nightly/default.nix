{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  installShellFiles,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  dbus,
  expat,
  glib,
  libgbm,
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
  systemd,
  unzip,
  nodejs-slim_26,
  python3,
  vulkan-loader,
  callPackage,
  cloudflared,
  llm-agents,
}:

let
  sources = lib.importJSON ./sources.json;
  platform =
    {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    }
    .${stdenv.hostPlatform.system};

  # T3 downloads Chrome for Testing into ~/.t3/tools. nix-ld supplies its
  # interpreter, but the downloaded browser also needs these libraries. They go
  # through NIX_LD_LIBRARY_PATH, which only nix-ld (foreign binaries) reads: as
  # LD_LIBRARY_PATH they reached every Nix program T3 started, and one built
  # against an older glibc then failed with "GLIBC_2.43 not found".
  browserLibraries = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    dbus
    expat
    glib
    libgbm
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
    systemd
  ];
  browserLibraryPath = lib.makeLibraryPath browserLibraries;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-nightly";
  inherit (sources) version;

  # Prebuilt Node SEA plus the native node_modules it loads beside itself;
  # nightlies change pnpm deps too often to rebuild from source per release.
  # The SEA's bundled server is unpacked, patched and packed again on
  # nixpkgs' Node (upstream pins the same major).
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-${platform}.tar.gz";
    hash = sources.${stdenv.hostPlatform.system}.cli;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    installShellFiles
    nodejs-slim_26
    python3
  ];

  # libstdc++ for node-pty, libvulkan for the transcribe-cpp ggml Vulkan
  # backend.
  buildInputs = [
    (lib.getLib stdenv.cc.cc)
    vulkan-loader
  ];

  prePatch = ''
    python3 -I ${./sea-unpack.py} t3 sea "$PWD/t3"
  '';

  # Plain-http links to an encrypted overlay such as Nebula, which upstream
  # only allows for Tailscale; see UPSTREAM-WORKAROUNDS.md#t3code-nightly-trusted-networks.
  patches = [ ./trusted-networks.patch ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    node --build-sea sea/sea-config.json
    rm -r sea
    runHook postBuild
  '';

  # Stripping would rewrite the SEA binary that carries its app blob in a note.
  dontStrip = true;
  # The hook would also rewrite t3, which is nixpkgs' Node and already finds
  # its libraries.
  dontAutoPatchelf = true;

  # The SEA resolves client/, node_modules/ and resource-monitor/ next to its
  # real path, so keep the tarball layout intact under libexec. ffi-rs and Koffi
  # pick their glibc builds on glibc, so the musl ones would only fail
  # autoPatchelf.
  installPhase = ''
    runHook preInstall

    rm -r node_modules/@yuuang/ffi-rs-linux-*-musl node_modules/@koromix/koffi-linux-*/musl_*
    mkdir -p $out/libexec $out/bin
    cp -r . $out/libexec/t3code

    # Same provider CLIs on PATH as the stable llm-agents wrapper. T3 Connect
    # otherwise downloads its pinned cloudflared relay client into ~/.t3.
    makeWrapper $out/libexec/t3code/t3 $out/bin/t3 \
      --prefix PATH : ${lib.makeBinPath llm-agents.t3code.providerPackages} \
      --prefix NIX_LD_LIBRARY_PATH : ${browserLibraryPath} \
      --set-default T3CODE_CLOUDFLARED_PATH ${lib.getExe cloudflared}

    runHook postInstall
  '';

  postFixup = ''
    autoPatchelf $(find $out/libexec/t3code -mindepth 1 -maxdepth 1 ! -name t3)
    for shell in bash fish zsh; do
      # Process substitution hides the generator's exit status, accepting
      # partial output even when the executable fails.
      HOME=$TMPDIR timeout 30 "$out/bin/t3" --completions "$shell" > "$TMPDIR/t3.$shell"
      installShellCompletion --cmd t3 --"$shell" "$TMPDIR/t3.$shell"
    done
  '';

  # Preview automation fails with "No preview automation host" when the
  # downloaded browser misses a library from the wrapper's NIX_LD_LIBRARY_PATH.
  # The sandbox has no nix-ld, so ldd resolves the same list via LD_LIBRARY_PATH.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ unzip ];
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$(mktemp -d)"
    actualVersion="$(timeout 30 "$out/bin/t3" --version)"
    if [[ "$actualVersion" != "t3 v${finalAttrs.version}" ]]; then
      echo "ERROR: expected t3 v${finalAttrs.version}, got $actualVersion" >&2
      exit 1
    fi
    timeout 30 "$out/bin/t3" --help > /dev/null
    timeout 30 "$out/libexec/t3code/resource-monitor/${platform}/t3-resource-monitor" \
      < /dev/null > "$TMPDIR/resource-monitor.json"
    grep -F '"type":"hello"' "$TMPDIR/resource-monitor.json" > /dev/null
    source ${./check-trusted-networks.sh}
    assertTrustedNetworks "$out/bin/t3"
    source ${./check-libraries.sh}
    LD_LIBRARY_PATH=${browserLibraryPath} assertHeadlessShellResolved ${
      callPackage ./headless-shell.nix { }
    }
    runHook postInstallCheck
  '';

  meta = {
    description = "Control surface for coding agents (nightly build)";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    # `node --build-sea` output fails on arm64 kernels with 16 or 64 KiB pages
    # (https://github.com/nodejs/node/issues/67048). Upstream injects the blob
    # with postject instead (scripts/lib/linux-arm64-sea.ts); add aarch64-linux
    # once Node fixes it or the repack does the same.
    platforms = [ "x86_64-linux" ];
    mainProgram = "t3";
  };
})
