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
  # interpreter, but the downloaded browser also needs these libraries.
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
in
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-nightly";
  inherit (sources) version;

  # Prebuilt Node SEA plus the native node_modules it loads beside itself;
  # nightlies change pnpm deps too often to rebuild from source per release.
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${finalAttrs.version}/t3-${finalAttrs.version}-${platform}.tar.gz";
    hash = sources.${stdenv.hostPlatform.system}.cli;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    installShellFiles
  ];

  # libstdc++ for node-pty, libatomic for the SEA itself.
  buildInputs = [ (lib.getLib stdenv.cc.cc) ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping would rewrite the SEA binary that carries its app blob in a note.
  dontStrip = true;
  # Implicit postFixup runs before the hook's own pass; patch first so the
  # completions below can execute t3.
  dontAutoPatchelf = true;

  # The SEA resolves client/, node_modules/ and resource-monitor/ next to its
  # real path, so keep the tarball layout intact under libexec.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec $out/bin
    cp -r . $out/libexec/t3code

    # Same provider CLIs on PATH as the stable llm-agents wrapper. T3 Connect
    # otherwise downloads its pinned cloudflared relay client into ~/.t3.
    makeWrapper $out/libexec/t3code/t3 $out/bin/t3 \
      --prefix PATH : ${lib.makeBinPath llm-agents.t3code.providerPackages} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath browserLibraries} \
      --set-default T3CODE_CLOUDFLARED_PATH ${lib.getExe cloudflared}

    runHook postInstall
  '';

  postFixup = ''
    autoPatchelf $out
    for shell in bash fish zsh; do
      HOME=$TMPDIR installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  meta = {
    description = "Control surface for coding agents (nightly build)";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "t3";
  };
})
