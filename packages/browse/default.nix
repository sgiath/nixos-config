{
  lib,
  stdenv,
  importNpmLock,
  makeWrapper,
  nodejs,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "browse";
  version = (lib.importJSON ./package-lock.json).packages."node_modules/@opencode/browse".version;
  src = ./.;

  npmDeps = importNpmLock { npmRoot = ./.; };
  npmRebuildFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [
    nodejs
    importNpmLock.npmConfigHook
    makeWrapper
  ];

  dontBuild = true;

  # The tree `npm install -g` leaves under `<prefix>/lib/node_modules`. With
  # npm_config_prefix pointing here, `npm root -g` is this package's own
  # parent, so `browse install` adopts it instead of running
  # `npm install -g @opencode/browse` (cli/src/setup/mcp.ts installRuntime).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r node_modules $out/lib/node_modules
    rm -rf $out/lib/node_modules/.bin $out/lib/node_modules/.package-lock.json

    # Nix owns the version: the relay would otherwise check npm hourly and
    # run `npm install -g` into the read-only store.
    makeWrapper ${lib.getExe nodejs} $out/bin/browse \
      --add-flags $out/lib/node_modules/@opencode/browse/dist/cli.mjs \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]} \
      --set npm_config_prefix $out \
      --set OPENCODE_BROWSER_AUTO_UPDATE off \
      --set OPENCODE_BROWSER_UPDATE_CHECK 0

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test "$(HOME=$TMPDIR $out/bin/browse --version)" = ${finalAttrs.version}

    runHook postInstallCheck
  '';

  meta = {
    description = "Drive your own Chromium from agents through the browse extension (CLI and MCP server)";
    homepage = "https://github.com/anomalyco/browse";
    license = lib.licenses.mit;
    mainProgram = "browse";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
