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
  version = "2.4.2";
  pname = "5etools";

  imgHashes = [
    {
      name = "img-v${version}.zip";
      hash = "sha256-t+f6NtlqPlVh0O5xMPH1+ktShtcXZCtCG/p5SLZxrFY=";
    }
    {
      name = "img-v${version}.z01";
      hash = "sha256-j+svveFC7/6tRwoloaSFC7pBkB0Ga6Htoxe1/QYe2bg=";
    }
    {
      name = "img-v${version}.z02";
      hash = "sha256-4AVMpcSOAKI/U8wGWHKEfeJ8boGhWRzCTSPbJtfix40=";
    }
    {
      name = "img-v${version}.z03";
      hash = "sha256-yYUEwwzb+tITiPxL4pAaMhNEBUYzq2MNgP59bpOoSy8=";
    }
    {
      name = "img-v${version}.z04";
      hash = "sha256-yeTVWsRuS1VCjP4yjAigQLROGRNMHwHLWEy6gowyzvE=";
    }
    {
      name = "img-v${version}.z05";
      hash = "sha256-4S7iGv91530N+r/jOWwS0zhnnWjV9m+uYKiGAxtmJVw=";
    }
    {
      name = "img-v${version}.z06";
      hash = "sha256-jmKtH8ndiJEGc7xzCAWjp/3qXnvm5UKQWKK8VN79jWw=";
    }
    {
      name = "img-v${version}.z07";
      hash = "sha256-q9ikjM2BIl8G/xbzHJAkAUg1lKerQafMPOMnuVG8OPM=";
    }
    {
      name = "img-v${version}.z08";
      hash = "sha256-poivWmyjTVZZT3BZpGAnJHRzqpFB9atJ0kzbmUOEVqc=";
    }
    {
      name = "img-v${version}.z09";
      hash = "sha256-WERb9BJei9qX1p2wwIQRBcTiKmAt4HJuipVx0OS6WWE=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/${v.name}";
      };
    in
    "cp ${img} ${v.name}"
  );

  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit version pname;

  src = fetchzip {
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-kIXgWA9KZp/vIGApH5kCnzYr4HB65uG4tQmBcUK8VbM=";
  };

  buildInputs = [
    nodejs
    p7zip
  ];

  buildPhase = ''
    # copy images
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # unpack images
    7z x -aoa img-v${version}.zip

    # remove ZIP files
    rm -f img-v*

    # link Node deps
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    # generate service worker
    npm run build:sw:prod
  '';

  installPhase = ''
    cp -r ./ $out/
  '';
}
