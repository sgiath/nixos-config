{
  deno,
  fetchFromGitHub,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "linear-cli";
  version = "2.1.1";

  src = fetchFromGitHub {
    owner = "schpet";
    repo = "linear-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aiTHUH0mxhGSnH7kmsVTk2TsXe5SbXcsawVOqUPbd/o=";
  };

  nativeBuildInputs = [ deno ];

  dontStrip = true;

  buildPhase = ''
    runHook preBuild

    export DENO_DIR="$TMPDIR/deno-dir"
    export DENO_NO_UPDATE_CHECK=1

    deno task codegen
    deno compile --allow-all --quiet --output linear src/main.ts

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 linear "$out/bin/linear"
    install -Dm644 LICENSE "$out/share/licenses/${finalAttrs.pname}/LICENSE"
    install -Dm644 README.md "$out/share/doc/${finalAttrs.pname}/README.md"
    install -Dm644 CHANGELOG.md "$out/share/doc/${finalAttrs.pname}/CHANGELOG.md"

    runHook postInstall
  '';

  meta = {
    description = "CLI tool for Linear that opens issues and team pages from branch and directory names";
    homepage = "https://github.com/schpet/linear-cli";
    license = lib.licenses.mit;
    mainProgram = "linear";
    platforms = lib.platforms.linux;
  };

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-OCRJSYNncaiTbXlqDFEjPeasJPTSJ3SYCuG6rrwQvBs=";
})
