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
  version = "2.5.1";
  pname = "5etools";

  imgHashes = [
    {
      name = "zip";
      hash = "sha256-l1ZNLP80GCREH3cjeBy8oDM+dbWu152AaiQLyUKYTWc=";
    }
    {
      name = "z01";
      hash = "sha256-jwSoihKNck8Gn/wruOiuOpv5M8owBCTd/jesFE+XXHk=";
    }
    {
      name = "z02";
      hash = "sha256-jvkCikDQEDT+EOO/U6l4qTLgvBFTkNONZprsByhsE+o=";
    }
    {
      name = "z03";
      hash = "sha256-B4opcwTEtLtBns0mbYXapXoWU8M0HLPUSKTCF/dCr8c=";
    }
    {
      name = "z04";
      hash = "sha256-ffdwUTV1W9UdVLBDayyJw4rXsjOvmMjwDAVKt2zE96Q=";
    }
    {
      name = "z05";
      hash = "sha256-YZLUNMgV5vJK/OYEK4y1NHckAbYX8cLeWImQPd970bY=";
    }
    {
      name = "z06";
      hash = "sha256-mpCJFH7OcoewKuMiH6fzeqlzfIGrqCIJ3ktg6ZaNH90=";
    }
    {
      name = "z07";
      hash = "sha256-V+RY+USBsUfu73T4YQpQ5+nbTZ+z+Jk7dotVkJYwMCo=";
    }
    {
      name = "z08";
      hash = "sha256-JMv9MgZcpgN2Yf89ZW4chmPY2rT/ZTn7vOVTW9qhpaA=";
    }
    {
      name = "z09";
      hash = "sha256-toTq8qI2YoWjJKDCHjNwKasWd9N/ZW4emRnDEw7+r8g=";
    }
    {
      name = "z10";
      hash = "sha256-h7HdMkmDnY7hDWBx6+oYO9MmKE4bJdwZbLdvw7mUal0=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        inherit version;
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${version}/img-v${version}.${v.name}";
      };
    in
    "cp ${img} img-v${version}.${v.name}"
  );

  nodeDependencies = (callPackage ./deps { inherit nodejs; }).nodeDependencies;
in
stdenv.mkDerivation {
  inherit  pname;
  version = "2.6.0";

  src = fetchzip {
    pname = "5etools-src";
    version = "2.6.0";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-73R5DeNDw5I2Xk800Vszmd3o9EpUgC0ZErBxaJ+S7zE=";
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
