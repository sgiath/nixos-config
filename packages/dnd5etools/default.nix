{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.26.0";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-1AG6XNbqoHDTj6z8FbHV2xOJZ5dD/bWBtXwdDEg5KSM=";
    }
    {
      name = "z02";
      hash = "sha256-ag7rUFQAjd9NalTgfIp8prAXO06BUU5/1J0FjSbQEbI=";
    }
    {
      name = "z03";
      hash = "sha256-VLsxTFeCwaOjwZ19CwuwrfmlvRMPahlp/Pd0DHy0TSk=";
    }
    {
      name = "z04";
      hash = "sha256-eOJgBptjbT7KAkdQuvxhbEMbK5wK9VMOqE93wPPYNss=";
    }
    {
      name = "z05";
      hash = "sha256-6kvqJU+/FiLHJRZED6DN8JYvDydz93TPNx6ATnG5/nQ=";
    }
    {
      name = "z06";
      hash = "sha256-R65VsjbklB+vdXhi5gA6SJ5W4oes1Exg70kPwtSK5lo=";
    }
    {
      name = "z07";
      hash = "sha256-vbqaigXc6LdHNNyScNoAAU3C2YonBpVHUpXKkxH1nPo=";
    }
    {
      name = "z08";
      hash = "sha256-sQ23Un4qQ914BJn/7ZAV59gxhI0CspNZVJBIt/IiFdA=";
    }
    {
      name = "z09";
      hash = "sha256-fKQLLHzStvtlRCyIQ1id1Pf3QJgGoxeMHjn+TzBlajc=";
    }
    {
      name = "z10";
      hash = "sha256-fpwvIN2/3CwM2hh1UcTnjungTvQbQDDoZbQAy0RqPd8=";
    }
    {
      name = "z11";
      hash = "sha256-kePztbrxJXLjuVQQ19gsboncuHovP6984zWP1YZfsMk=";
    }
    {
      name = "zip";
      hash = "sha256-kv1gRchqn+JE4w+ILPzqFt3FJQeZoEtcuLPuMJCh/VM=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.26.0";
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
    hash = "sha256-hIccaHc9ysrMp3SM/pQ02ADg7Azwrf0g6iMqpUy+fDU=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-mCJ+8sGJDXCLEDNNfZVFr0kQY8Evj5y/wrGuqWppB4w=";

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
