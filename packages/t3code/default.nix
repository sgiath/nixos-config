{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "t3code";
  version = "0.0.13";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-oHKIh+aHsbGVHEoLLjItl6AbVRwvWVlZaIWyHKiekVc=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/t3-code-desktop.desktop \
      $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} --no-sandbox %U'

    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/1024x1024/apps/t3-code-desktop.png \
      $out/share/icons/hicolor/1024x1024/apps/t3-code-desktop.png
  '';

  meta = with lib; {
    description = "Minimal desktop GUI for coding agents";
    homepage = "https://github.com/pingdotgg/t3code";
    license = licenses.mit;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
