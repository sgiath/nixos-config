{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.30.1";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-h/kQ83L4FK97wRuTy4xc4/sPtSvIBvw8ogchhhKQANg=";
    }
    {
      name = "z02";
      hash = "sha256-hSLfNtgLRZHLmVA4j6pZoktX5oX6I7GF0bzrAAWDznk=";
    }
    {
      name = "z03";
      hash = "sha256-fybtP80gGvCn+16sc+n3z9BIZxEBgJZbtJtHdlDwq/g=";
    }
    {
      name = "z04";
      hash = "sha256-SZIoQiNWIY+/CZ9NsMpvjl8cna1xNmdDQQyKwF0jnqM=";
    }
    {
      name = "z05";
      hash = "sha256-3u7HWCTC6ivaAF9TVf9gB0Zk54GdbESXC581zg7ZGXI=";
    }
    {
      name = "z06";
      hash = "sha256-nBFmtbvrCnGe1HoOmSOWw3b2hsXzmH3hC5R8cHFjotw=";
    }
    {
      name = "z07";
      hash = "sha256-2U2QaZDX1W9C+Dwh05OB2Eei5p+CrbUQWkSUK5E2Hgg=";
    }
    {
      name = "z08";
      hash = "sha256-tUv47QX6A6mNCIkhsVeUvOCtE2qA01U19MTci+iT8DI=";
    }
    {
      name = "z09";
      hash = "sha256-G9H6BphG+sTp8l2uzVeUt6aPADSk7OE1hUimSHCNe4I=";
    }
    {
      name = "z10";
      hash = "sha256-nh1iV4U2AVEvve3lF/1gUVjQzY5j1ngl4hbVr7z3iQ4=";
    }
    {
      name = "z11";
      hash = "sha256-Ebalams81wOy2KKNUNKELYYOTYH4wLCzFXxQiTYGsGk=";
    }
    {
      name = "z12";
      hash = "sha256-PmgrtiPpqyU5pxNqVFdCkHvUpbwhHHx/3LA6Uo8LjyM=";
    }
    {
      name = "zip";
      hash = "sha256-fsUTV9/yd81/p6xKs67kMXwcjWEPE2cmfKK+pv8mEtg=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.30.0";
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
    hash = "sha256-dxJ8p+sjs9+ekeAlQYbb1GB2Y0vbMwvp5XbTI/nJZcg=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-ZX9Xp2GXMnGDFlTluraYel6lCd0NbfPyXalipe/+V00=";

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
