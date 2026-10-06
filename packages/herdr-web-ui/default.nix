{
  lib,
  stdenv,
  fetchFromGitHub,
  autoPatchelfHook,
  bun,
  git,
  herdr,
  makeWrapper,
  nodejs,
  openssh,
  writableTmpDirAsHomeHook,
}:

let
  # bun installs only the optional dependencies of the build platform
  # (@lydell/node-pty, esbuild, rollup prebuilts), so this hash is valid for
  # x86_64-linux only; see meta.platforms.
  node_modules =
    finalAttrs:
    stdenv.mkDerivation {
      pname = "${finalAttrs.pname}-node_modules";
      inherit (finalAttrs) version src;

      impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
        "GIT_PROXY_COMMAND"
        "SOCKS_SERVER"
      ];

      nativeBuildInputs = [
        bun
        writableTmpDirAsHomeHook
      ];

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
        bun install \
          --frozen-lockfile \
          --ignore-scripts \
          --no-progress

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        cp -R node_modules $out

        runHook postInstall
      '';

      # A fixed-output derivation must not reference store paths.
      dontFixup = true;

      outputHash = "sha256-DzYjHIJmBdeFAcSgidBVPPBM2ZoW75pOqDnErUfD8KE=";
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-web-ui";
  version = "0.3.51";

  src = fetchFromGitHub {
    owner = "devswha";
    repo = "herdr-web-ui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-kw55170XVZ54uoamGtRTgM7LLscRo5qLaASkymjRFck=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    nodejs
  ];

  # The @lydell/node-pty prebuilt links libstdc++.
  buildInputs = [ (lib.getLib stdenv.cc.cc) ];

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.passthru.node_modules} node_modules
    chmod -R u+w node_modules
    # bun installs rollup's musl prebuilt beside the glibc one; nothing loads it
    # here and autoPatchelf cannot resolve its musl libc.
    rm -r node_modules/@rollup/rollup-linux-x64-musl

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # `bun run build` would exec node_modules/.bin/vite through its
    # `#!/usr/bin/env node` shebang.
    node node_modules/vite/bin/vite.js build

    runHook postBuild
  '';

  # Only server/index.ts runs: it serves dist/ relative to its own source
  # (server/static.ts), imports a few modules from src/lib, and writes state
  # only to HERDR_WEB_STATE_DIR (default ~/.config/herdr-web-ui) and its bridge
  # registry in ~/.config/herdr-web-ui/bridges, so a read-only store tree
  # works. The managed launcher (server/managed.ts, scripts/plugin.ts) polls
  # GitHub releases and rebuilds itself in place; it is not exposed.
  installPhase = ''
    runHook preInstall

    app=$out/lib/herdr-web-ui
    mkdir -p $app
    cp -R package.json dist node_modules server shared src $app/

    makeWrapper ${lib.getExe bun} $out/bin/herdr-web-ui \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs
          herdr
          openssh
          git
        ]
      } \
      --add-flags $app/server/index.ts

    runHook postInstall
  '';

  passthru.node_modules = node_modules finalAttrs;

  meta = {
    description = "Browser UI for herdr workspaces, panes and agents";
    homepage = "https://github.com/devswha/herdr-web-ui";
    changelog = "https://github.com/devswha/herdr-web-ui/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "herdr-web-ui";
  };
})
