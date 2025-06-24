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
  version = "2.9.1";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-UjkkOh2YnqT0zY16YSUNi7wDMv3PdTfO0A4gWOB1++8=";
    }
    {
      name = "z02";
      hash = "sha256-c12EJXRBteS/yLewM9x9ccDzWnKu+RlAwm/YOQ1b2H0=";
    }
    {
      name = "z03";
      hash = "sha256-BjLkuvIRYD5ZM1Cj7em22kqEl8mlbXPXAIiE9cmfCsw=";
    }
    {
      name = "z04";
      hash = "sha256-s4H9ZF+lBa+jeZ+SA/N813XgpV0yNQ4oPNewQWEpwXE=";
    }
    {
      name = "z05";
      hash = "sha256-eCvROi136tnFjDuJR23xvburEM2guvpn+0uvuOzcNNM=";
    }
    {
      name = "z06";
      hash = "sha256-8cWcHXPHk+Df8WIzLJMezg8GIgrwBkGvvph3g4ie4ZA=";
    }
    {
      name = "z07";
      hash = "sha256-Ogu6SdUni4IUPSOCGNQ2zhiTrAcMMmV/QLkRi8SKkmE=";
    }
    {
      name = "z08";
      hash = "sha256-3uo6+3FVPmsqYnvaD3wyaxUDre65lra9hLiomX1xgVo=";
    }
    {
      name = "z09";
      hash = "sha256-woIAWaE2FhwIVTY8myuwLYf02Reyn8KYa/binsnNayw=";
    }
    {
      name = "z10";
      hash = "sha256-uvmM2mxX+4ZD4boZ3999/LpRuOsqGqnzJJxAi1W4vpo=";
    }
    {
      name = "zip";
      hash = "sha256-sk7BaBeZxzgLH2F6O2ll8CQ35Y58GyCQUB7CLTqu63c=";
    }
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
    hash = "sha256-0zTM/1ms4fXMc+MRRZdnB4Dh4q7Ma4h25LObtBT2yUw=";
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
