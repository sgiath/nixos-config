{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.37.0";
  pname = "5etools";

  img = import ./imgHashes.nix;

  copyImgs = lib.lists.forEach img.hashes (
    v:
    let
      archive = fetchurl {
        pname = "5etools-img-${v.name}";
        inherit (img) version;
        inherit (v) hash;
        url = "https://github.com/5etools-mirror-2/5etools-img/releases/download/v${img.version}/img-v${img.version}.${v.name}";
      };
    in
    "cp ${archive} img-v${img.version}.${v.name}"
  );
in
buildNpmPackage {
  inherit version pname;

  src = fetchzip {
    inherit version;
    pname = "5etools-src";
    url = "https://github.com/5etools-mirror-3/5etools-src/releases/download/v${version}/${pname}-v${version}.zip";
    stripRoot = false;
    hash = "sha256-+gBHWCtRa0V7Bkqa6uD72gNDb8K1578qGZx3m5k+0f0=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-BY6c2pPe/HYGTK+nw352Ajml6qMp2g5lxu3zeFw0QS0=";

  nativeBuildInputs = [ p7zip ];

  preBuild = ''
    # Copy image archives
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # Unpack images (split 7z archive)
    ${lib.getExe p7zip} x -aoa img-v${img.version}.zip

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
