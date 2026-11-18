{
  lib,
  stdenvNoCC,
  fetchurl,
  runtimeShell,
}:

let
  version = "0.1.5";

  # Upstream publishes static musl binaries only to npm; the GitHub release
  # carries just the extension and the Node launcher.
  targets = {
    x86_64-linux = {
      target = "linux-x64-musl";
      hash = "sha256-R7NP2YkSwJco1The86pxL4b1/j3+6G6tOO1kWinZXRk=";
    };
    aarch64-linux = {
      target = "linux-arm64-musl";
      hash = "sha256-l/f5WijB0OirZCx4uNYQqxEtgFim+93zYFY2jXCrMyg=";
    };
  };

  platform =
    targets.${stdenvNoCC.hostPlatform.system}
      or (throw "browse: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "browse";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/browse-${platform.target}/-/browse-${platform.target}-${version}.tgz";
    inherit (platform) hash;
  };

  sourceRoot = "package";
  dontBuild = true;
  dontStrip = true;

  # Nix owns the version: auto-update is forced off, and `browse install`
  # is refused because it copies any binary it does not recognise as its own
  # install (a store path included) into a mutable user directory, even with
  # updates off. `browse pair` pairs a browser without that copy.
  installPhase = ''
    runHook preInstall

    install -Dm755 bin/browse $out/libexec/browse/browse
    mkdir -p $out/bin
    cat > $out/bin/browse <<EOF
    #!${runtimeShell}
    if [ "\''${1-}" = install ]; then
      echo "browse: this binary is managed by Nix; 'browse install' would copy it out of the store." >&2
      echo "browse: pair a browser with 'browse pair' and configure MCP clients through Nix or their own config." >&2
      exit 2
    fi
    export OPENCODE_BROWSER_AUTO_UPDATE=off
    export OPENCODE_BROWSER_UPDATE_CHECK=0
    exec $out/libexec/browse/browse "\$@"
    EOF
    chmod +x $out/bin/browse

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test "$(HOME=$TMPDIR $out/bin/browse --version)" = ${version}
    ! HOME=$TMPDIR $out/bin/browse install 2>/dev/null

    runHook postInstallCheck
  '';

  meta = {
    description = "Drive your own Chromium from agents through the browse extension (CLI and MCP server)";
    homepage = "https://github.com/anomalyco/browse";
    license = lib.licenses.mit;
    mainProgram = "browse";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames targets;
  };
}
