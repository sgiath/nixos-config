{
  fetchurl,
  installShellFiles,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation rec {
  pname = "grok";
  version = "0.2.14";

  src = fetchurl {
    url = "https://x.ai/cli/grok-${version}-linux-x86_64";
    hash = "sha256-B78S/zoE2vo6LemYcJH7onU+/DRNE7F7KzgaEX55NBg=";
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/grok"
    ln -s grok "$out/bin/agent"

    "$out/bin/grok" completions bash > grok.bash
    "$out/bin/grok" completions fish > grok.fish
    "$out/bin/grok" completions zsh > _grok
    installShellCompletion --bash grok.bash --fish grok.fish --zsh _grok

    runHook postInstall
  '';

  meta = {
    description = "Grok CLI from xAI";
    homepage = "https://x.ai/cli";
    license = lib.licenses.unfree;
    mainProgram = "grok";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
