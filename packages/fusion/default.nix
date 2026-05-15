{
  autoPatchelfHook,
  buildNpmPackage,
  fetchurl,
  git,
  lib,
  makeWrapper,
  stdenv,
}:

buildNpmPackage rec {
  pname = "fusion";
  version = "0.31.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@runfusion/fusion/-/fusion-${version}.tgz";
    hash = "sha512-EMmnePCVfOkkoSHvvE5JAWmmLk9RsuB0A1MVubdiThLNRhOcFoAzbI/OUIS6SmJB7JLmoALehlUuEQpwfBsCdw==";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-kZj1IBAQ6gDKpgt0J9WWbRmQtRRAD+9bc53ElJoFfqY=";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dontNpmBuild = true;

  npmFlags = [
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];

  postInstall = ''
    packageRoot="$out/lib/node_modules/@runfusion/fusion"

    mkdir -p "$out/lib/node_modules/@runfusion/skill"
    cp -R "$packageRoot/skill/fusion" "$out/lib/node_modules/@runfusion/skill/fusion"

    find "$packageRoot/node_modules/node-pty/prebuilds" -mindepth 1 -maxdepth 1 ! -name linux-x64 -exec rm -rf {} +
    rm -f "$packageRoot"/node_modules/node-pty/prebuilds/linux-x64/*.musl.node

    find "$packageRoot/node_modules/koffi/build/koffi" -mindepth 1 -maxdepth 1 ! -name linux_x64 -exec rm -rf {} +

    wrapProgram "$out/bin/fusion" \
      --prefix PATH : "${lib.makeBinPath [ git ]}"

    wrapProgram "$out/bin/fn" \
      --prefix PATH : "${lib.makeBinPath [ git ]}"
  '';

  meta = {
    description = "Multi-node agent orchestrator for tasks, agents, missions, git, files, and worktrees";
    homepage = "https://github.com/Runfusion/Fusion";
    license = lib.licenses.mit;
    mainProgram = "fusion";
    platforms = lib.platforms.unix;
  };
}
