{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  lib,
  makeWrapper,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "fusion";
  version = "0.31.0";

  src = fetchFromGitHub {
    owner = "Runfusion";
    repo = "Fusion";
    tag = "v${finalAttrs.version}";
    hash = "sha256-lkj2j8dgr+ORniqMws7oRlMBPfHVPuHixaJ/6Y3XCB0=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    hash = "sha256-KWoswBIdDvQe1gFEd2QGT6GN88PIw9eNHYhPu8CgWIk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    pnpm_10
    pnpmConfigHook
  ];

  buildInputs = [
    nodejs
    stdenv.cc.cc.lib
  ];

  buildPhase = ''
    runHook preBuild

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
