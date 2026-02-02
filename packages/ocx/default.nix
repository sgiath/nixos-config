{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "ocx";
  version = "1.4.6";

  src = fetchurl {
    url = "https://github.com/kdcokenny/ocx/releases/download/v${version}/ocx-linux-x64";
    hash = "sha256-VT+jBXmfRD280lCX+nUizGtdtjW3WKmkNjAT6w9va0c=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/ocx

    runHook postInstall
  '';

  dontStrip = true;

  meta = {
    description = "OpenCode extension manager with portable, isolated profiles";
    homepage = "https://github.com/kdcokenny/ocx";
    changelog = "https://github.com/kdcokenny/ocx/releases/tag/v${version}";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ocx";
  };
}
