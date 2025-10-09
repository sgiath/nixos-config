{
  lib,
  callPackage,
  stdenv,
  fetchurl,
  fetchzip,
  nodejs,
  p7zip,
  ...
}:
let
  version = "2.13.0";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-1IDVNYnAfUh2A2dJ4+lcCzblGIcXCiVjwYpLzB5EW5I=";
    }
    {
      name = "z02";
      hash = "sha256-mHNOM4ZI34JBBZjsIm3Wrfe220qv8DmYKr3HdEN1Jxg=";
    }
    {
      name = "z03";
      hash = "sha256-0P71pBwZVAbJVuyRGg+EcgUE50p0rG3lR8EIr/i+XZU=";
    }
    {
      name = "z04";
      hash = "sha256-YivE+gXRvd6Q6l4NUMTyf5ynpHzvnAeZDjJ7lDWQYI0=";
    }
    {
      name = "z05";
      hash = "sha256-0uLyv7kZc0O8TefrTnUD+d230QffWSMIK9Du9hweOWU=";
    }
    {
      name = "z06";
      hash = "sha256-OJZ4ez/XvKetX46YDYLVTcL3RjHNeGR0HR7EjvtF7+A=";
    }
    {
      name = "z07";
      hash = "sha256-+CkRs81UH4QjFLV33tynd1YjWp22fCQtRwIR3hAAE94=";
    }
    {
      name = "z08";
      hash = "sha256-CYciOSvZh5hyNFL3ElFZbbQ9rfAvCJ00LkwwimVlZG0=";
    }
    {
      name = "z09";
      hash = "sha256-5aCFt0uPuiNT+hnn7eppto7mttH5966vnTZz9W0yn1c=";
    }
    {
      name = "z10";
      hash = "sha256-19QQf7vFRW+8p0fxU2Y0IubkqpkcMslMEHkq/XHr6cM=";
    }
    {
      name = "zip";
      hash = "sha256-0dUeC7ObUd5rFIFfJjMbTeYihT/Y2+f5Tf0tDwPCSxY=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.12.0";
        # inherit version;
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );

  # to update copy new package.json and package-lock.json and run:
  # node2nix -i package.json -l package-lock.json -d
  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-+ULTH5UE/pCd4TmhlclFOWkwkEpuX0mP9kAN7YpF35M=";
  };

  buildInputs = [
    nodejs
    p7zip
  ];

  buildPhase = ''
    # copy images
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # unpack images
    ${p7zip}/bin/7z x -aoa img-v${version}.zip

    # remove ZIP files
    rm -f img-v*

    # link Node deps
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    # generate service worker
    ${nodejs}/bin/npm run build:sw:prod
  '';

  installPhase = ''
    cp -r ./ $out/
  '';
}
