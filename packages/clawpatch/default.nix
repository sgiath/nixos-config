{
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  lib,
  makeWrapper,
  nodejs_22,
  pnpm_11,
  pnpmConfigHook,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "clawpatch";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "clawpatch";
    tag = "v${finalAttrs.version}";
    hash = "sha256-+4FxNes/lfEFpkEqAq4iQILrgOQBQRxAcfJ5MngO0vM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 3;
    hash = "sha256-Z7y+55VOopKN/evhyZ4KwuER0Ucfcz1K1SOiYmwk/LI=";
  };

  nativeBuildInputs = [
    makeWrapper
    pnpm_11
    pnpmConfigHook
  ];

  buildInputs = [
    nodejs_22
  ];

  buildPhase = ''
    runHook preBuild

    pnpm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    packageRoot="$out/lib/clawpatch"

    mkdir -p "$out/bin" "$packageRoot"
    cp -R dist node_modules package.json "$packageRoot/"

    makeWrapper ${lib.getExe nodejs_22} "$out/bin/clawpatch" \
      --add-flags "$packageRoot/dist/cli.js" \
      --prefix PATH : "${lib.makeBinPath [ git ]}"

    runHook postInstall
  '';

  meta = {
    description = "Automated code review that lands fixes";
    homepage = "https://github.com/openclaw/clawpatch";
    license = lib.licenses.mit;
    mainProgram = "clawpatch";
    platforms = lib.platforms.unix;
  };
})
