{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.28.0";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-s3JgZHDsJdwnScngwMlnVYeFhWHwcOxGfRJ0rPcGCSM=";
    }
    {
      name = "z02";
      hash = "sha256-Y1MF6vJknqKRs3o49AyFBOD0QwBdOsjvt12tX5OLpqw=";
    }
    {
      name = "z03";
      hash = "sha256-eajx1C/Chg4D5lVsczABdaq/FUw3K4BMd+hXX6yfw1A=";
    }
    {
      name = "z04";
      hash = "sha256-iyEO9LtZJxN8ITSCcaOA352avEk1pKduQGJeUhthb0w=";
    }
    {
      name = "z05";
      hash = "sha256-LVKG9CV/pVyfn+FSBZghNdRn8Z4xOu1T9SnhiH8d6XM=";
    }
    {
      name = "z06";
      hash = "sha256-Ol0xqjbKMdvR3b29eknfGqvOAzqAppBnMnphZ6OC1Xc=";
    }
    {
      name = "z07";
      hash = "sha256-hYUBOJB4UuqcR5CpG8ZcpYkSKkHkWjkM3WRDW0ttj+I=";
    }
    {
      name = "z08";
      hash = "sha256-P9qYhHVavVN6I+3EcVUeE+yLCEd0LG4oKld/32xmDMs=";
    }
    {
      name = "z09";
      hash = "sha256-8ujHMPBWZmgnjMBHxgpfvY/IQsq/epNH67cQkyjmgTs=";
    }
    {
      name = "z10";
      hash = "sha256-iDJ8YuGnpUq/ipeqWy/uwZ/2SlnKRA14kYUNtwSInLU=";
    }
    {
      name = "z11";
      hash = "sha256-02RgyJQtsx1QTSIs1HlhBZ3xtE/ifYUuxpDwB43K4rA=";
    }
    {
      name = "z12";
      hash = "sha256-SuaVRui3QbhzmVVffDX69dBCEqI43YUyxHjZma33Bpo=";
    }
    {
      name = "zip";
      hash = "sha256-93i0b3DL2m07/obgSJ8WXVlYwRgghevDgwV/IoceWzk=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.27.0";
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );
in
buildNpmPackage {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-mTYMqVWyCvduzhUVXuDX/Ifr/qsl6NYRD7ht3uKMz3U=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-stI3hfX5Pvg9u63yycLJ3gPKga02PD6wErYA7Y6hzYw=";

  nativeBuildInputs = [ p7zip ];

  preBuild = ''
    # Copy image archives
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # Unpack images (split 7z archive)
    ${lib.getExe p7zip} x -aoa img-v${version}.zip

    # Remove archive files
    rm -f img-v*
  '';

  # Build service worker
  npmBuildScript = "build:sw:prod";

  # Don't install as npm package - we want static files
  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    # Copy all static files
    cp -r ./ $out/

    # Remove unnecessary files from output
    rm -rf $out/node_modules
    rm -f $out/package*.json

    runHook postInstall
  '';
}
