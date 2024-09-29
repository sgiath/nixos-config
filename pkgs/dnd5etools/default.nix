{
  lib,
  stdenv,
  fetchzip,
  nodejs,
  ...
}:

stdenv.mkDerivation rec {
  pname = "5etools";
  version = "1.210.4";

  src = fetchzip {
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-kIXgWA9KZp/vIGApH5kCnzYr4HB65uG4tQmBcUK8VbM=";
  };

  buildInputs = [
    nodejs
  ];

  # buildPhase = ''
  #   npm i
  #   npm run build:sw:prod
  # '';

  installPhase = ''
    runHook preInstall

    ls -la .

    mkdir -p $out/share
    cp -r ./ $out/share

    runHook postInstall
  '';
}
