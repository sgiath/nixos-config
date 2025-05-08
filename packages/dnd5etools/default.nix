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
  version = "2.8.3";
  pname = "5etools";

  imgHashes = [
    # {
    #   name = "zip";
    #   hash = "";
    # }
    # {
    #   name = "z01";
    #   hash = "";
    # }
    # {
    #   name = "z02";
    #   hash = "";
    # }
    # {
    #   name = "z03";
    #   hash = "";
    # }
    # {
    #   name = "z04";
    #   hash = "";
    # }
    # {
    #   name = "z05";
    #   hash = "";
    # }
    # {
    #   name = "z06";
    #   hash = "";
    # }
    # {
    #   name = "z07";
    #   hash = "";
    # }
    # {
    #   name = "z08";
    #   hash = "";
    # }
    # {
    #   name = "z09";
    #   hash = "";
    # }
    # {
    #   name = "z10";
    #   hash = "";
    # }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.8.3";
        # inherit version;
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );

  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "";
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
