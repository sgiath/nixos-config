{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_10,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bird";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "bird";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4bXxaHCislWgOITqoWWc+MffhmhUdzuk9CBjKA24J5s=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 1;
    hash = "sha256-Q1ZgnQiqS94TM80/A3N0CDlOb/Ghi7nT2frOB3KMTsA=";
  };

  nativeBuildInputs = [
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ];

  buildInputs = [
    nodejs
  ];

  buildPhase = ''
    runHook preBuild

    pnpm run build:dist

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/bird}
    cp -r dist $out/lib/bird/
    cp -r node_modules $out/lib/bird/
    cp package.json $out/lib/bird/

    makeWrapper ${nodejs}/bin/node $out/bin/bird \
      --add-flags "$out/lib/bird/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Fast X/Twitter CLI for tweeting, replying, and reading via GraphQL API";
    homepage = "https://github.com/steipete/bird";
    changelog = "https://github.com/steipete/bird/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "bird";
  };
})
