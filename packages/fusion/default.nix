{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  lib,
  makeWrapper,
  node-gyp,
  nodejs,
  perl,
  pnpm_10,
  pnpmConfigHook,
  python3,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fusion";
  version = "0.35.0";

  src = fetchFromGitHub {
    owner = "Runfusion";
    repo = "Fusion";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+0x6ZA6GVL5mebErCLnr5jrWld1jh0Kr0JyZ2fp/b8g=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-Ja1dop7W4crXZE2wXkgbOVl4/r5IR4SEkRG79aZXN0s=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    node-gyp
    perl
    pnpm_10
    pnpmConfigHook
    python3
  ];

  buildInputs = [
    nodejs
    stdenv.cc.cc.lib
  ];

  postPatch = ''
    # Fusion tries to chmod node-pty native assets during terminal startup.
    # In the Nix store those files are already executable but read-only, so the
    # chmod repair logs a noisy EROFS warning. Ignore only that harmless case.
    perl -0pi -e 's#(\s*try \{\n\s*fs\.chmodSync\(nativeModulePath, 0o755\);\n\s*\} catch \(err\) \{\n)#\1      if (\n        err &&\n        typeof err === "object" &&\n        "code" in err &&\n        err.code === "EROFS" &&\n        fs.existsSync(nativeModulePath)\n      ) {\n        continue;\n      }\n\n#' packages/dashboard/src/terminal-service.ts

    grep -Fq 'err.code === "EROFS"' packages/dashboard/src/terminal-service.ts
  '';

  buildPhase = ''
    runHook preBuild

    # pnpm installs @homebridge/node-pty-prebuilt-multiarch without a usable
    # pty.node in this Nix build. Build the native addon locally so Fusion's
    # terminal service can load build/Release/pty.node at runtime.
    pushd node_modules/.pnpm/@homebridge+node-pty-prebuilt-multiarch@0.13.1/node_modules/@homebridge/node-pty-prebuilt-multiarch
    node-gyp rebuild
    popd

    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageRoot="$out/lib/fusion"

    mkdir -p "$out/bin" "$packageRoot" "$out/lib/node_modules/@runfusion/skill"
    cp -R package.json pnpm-lock.yaml node_modules "$packageRoot/"
    cp -R packages plugins "$packageRoot/"
    cp -R "$packageRoot/packages/cli/skill/fusion" "$out/lib/node_modules/@runfusion/skill/fusion"
    mkdir -p "$packageRoot/packages/skill"
    cp -R "$packageRoot/packages/cli/skill/fusion" "$packageRoot/packages/skill/fusion"

    find "$packageRoot" -path '*/node-pty-prebuilt-multiarch/prebuilds/*' ! -path '*/linux-x64/*' -exec rm -rf {} +
    find "$packageRoot" -path '*/node-pty-prebuilt-multiarch/prebuilds/linux-x64/*.musl.node' -delete

    find "$packageRoot" -path '*/koffi/build/koffi' -type d -print0 |
      while IFS= read -r -d "" koffiBuild; do
        find "$koffiBuild" -mindepth 1 -maxdepth 1 ! -name linux_x64 -exec rm -rf {} +
      done

    makeWrapper ${lib.getExe nodejs} "$out/bin/fusion" \
      --add-flags "$packageRoot/packages/cli/dist/bin.js" \
      --prefix PATH : "${lib.makeBinPath [ git ]}"

    makeWrapper ${lib.getExe nodejs} "$out/bin/fn" \
      --add-flags "$packageRoot/packages/cli/dist/bin.js" \
      --prefix PATH : "${lib.makeBinPath [ git ]}"

    runHook postInstall
  '';

  meta = {
    description = "Multi-node agent orchestrator for tasks, agents, missions, git, files, and worktrees";
    homepage = "https://github.com/Runfusion/Fusion";
    license = lib.licenses.mit;
    mainProgram = "fusion";
    platforms = lib.platforms.unix;
  };
})
