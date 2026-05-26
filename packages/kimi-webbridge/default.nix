{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "kimi-webbridge";
  version = "latest-2026-05-26";

  src = fetchurl {
    url = "https://kimi-web-img.moonshot.cn/webbridge/latest/releases/kimi-webbridge-linux-amd64";
    hash = "sha256-EZ+c1nW2iYT4fsvWrn1uCjrUKQl3oRD+U08otuqhnZw=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/kimi-webbridge"

    runHook postInstall
  '';

  meta = {
    description = "Kimi WebBridge daemon and toolkit";
    homepage = "https://kimi-web-img.moonshot.cn/webbridge/install.sh";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.unfree;
    mainProgram = "kimi-webbridge";
    platforms = [ "x86_64-linux" ];
  };
}
