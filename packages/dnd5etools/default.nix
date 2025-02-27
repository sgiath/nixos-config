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
  version = "2.7.2";
  pname = "5etools";

  imgHashes = [
    {
      name = "zip";
      hash = "sha256-3pGwExeNYGNlxtlf7SZ2ZPDeN75tTAU7wDEzlbYk3Po=";
    }
    {
      name = "z01";
      hash = "sha256-GvfMl3BTavXgMm+JpRxEYeDscQdh/X0Kynb0/H3gxeE=";
    }
    {
      name = "z02";
      hash = "sha256-WPd5PSR16VmwUfemD7Kop3CUVsvwgxK+H+R7IMtd4js=";
    }
    {
      name = "z03";
      hash = "sha256-ujl7NSQ163q20hZT63hdNnArC4RgxtYYTi8UNb74qfc=";
    }
    {
      name = "z04";
      hash = "sha256-/5UyXeYx/SnEoqgiE87j4jmw2pUVvUHZBb+sqzhKBUM=";
    }
    {
      name = "z05";
      hash = "sha256-RJ+petXlABOnj0EM5EG8GaOSD/Z64HAramUvFCz0OfA=";
    }
    {
      name = "z06";
      hash = "sha256-R5gCM7qYmMcmLhXklo5nWnS9goDcWxAoYGDni8Lp918=";
    }
    {
      name = "z07";
      hash = "sha256-ORJslbuj2u0U6v7/XwvLYKruvDpRHhC9xpWNr1tbmY8=";
    }
    {
      name = "z08";
      hash = "sha256-qu0ewudAbqkj6k0jX93eMXJRuu3zDSAPND0mBpmTDOo=";
    }
    {
      name = "z09";
      hash = "sha256-/i6W2nEDd2n+0IimfFp/7IHvTCPI0aLU1aRGu95lL4E=";
    }
    {
      name = "z10";
      hash = "sha256-K4xZ9x5+/+OGSqLuQRHBx8AXqalxCXTsKBG3KXMp/tA=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.7.2";
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
    hash = "sha256-4OJ24mSSDFmwnMOG/Q9tEH+NgWx9gS+Objwman1DAJk=";
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
