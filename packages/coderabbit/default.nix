{
  fetchurl,
  git,
  lib,
  makeWrapper,
  stdenv,
  unzip,
  xdg-utils,
}:

stdenv.mkDerivation rec {
  pname = "coderabbit";
  version = "0.5.2";

  src = fetchurl {
    url = "https://cli.coderabbit.ai/releases/${version}/coderabbit-linux-x64.zip";
    hash = "sha256-ybnZQkU+pGsXnQX/wPrrcXZ+8mSqiIAHgBA1AlIj4so=";
  };

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  dontStrip = true;
  dontPatchELF = true;

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 coderabbit "$out/bin/coderabbit"
    ln -s coderabbit "$out/bin/cr"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/coderabbit" \
      --prefix PATH : ${
        lib.makeBinPath [
          git
          xdg-utils
        ]
      }
  '';

  meta = {
    description = "CodeRabbit CLI for AI code reviews from the terminal";
    homepage = "https://cli.coderabbit.ai";
    license = lib.licenses.unfree;
    mainProgram = "coderabbit";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
