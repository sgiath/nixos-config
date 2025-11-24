{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "material-symbols";
  version = "4.0.0-unstable-2025-09-19";

  src = fetchFromGitHub {
    owner = "google";
    repo  = "material-design-icons";
    rev   = "bb04090f930e272697f2a1f0d7b352d92dfeee43";
    hash  = "sha256-aFKG8U4OBqh2hoHYm1n/L4bK7wWPs6o0rYVhNC7QEpI=";
    sparseCheckout = [ "variablefont" ];
  };

  installPhase = ''
    runHook preInstall

    # Tidy filenames (drop [FILL,GRAD,opsz,wght] suffix)
    for f in variablefont/*; do
      mv "$f" "''${f//\[FILL,GRAD,opsz,wght\]/}"
    done

    # Fonts should not be executable; install as 0644
    install -Dm444 variablefont/*.ttf -t $out/share/fonts/truetype

    runHook postInstall
  '';

  meta = {
    description = "Material Symbols icons by Google (variable fonts)";
    homepage    = "https://fonts.google.com/icons";
    license     = lib.licenses.asl20;
    platforms   = lib.platforms.all;
  };
}
