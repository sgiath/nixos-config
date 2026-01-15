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
  pname = "openspec";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    rev = "v${finalAttrs.version}";
    hash = "sha256-79Xb1NLBk04V/WVPu+8m1br/rsWoYDARc3+YoQJ8LRg=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 1;
    hash = "sha256-s12YVE4shSr1/0DYh5n36OYZFAmsUCW9SK31IRT93Oc=";
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
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/openspec}
    cp -r dist node_modules package.json $out/lib/openspec/

    makeWrapper ${nodejs}/bin/node $out/bin/openspec \
      --add-flags "$out/lib/openspec/dist/cli/index.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Spec-driven development (SDD) for AI coding assistants.";
    homepage = "https://openspec.dev/";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "openspec";
  };
})
