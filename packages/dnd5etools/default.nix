{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.29.0";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-ALfNN/uQwGYehzBa3x22H0r7Y1Gxf0Ei6F6bEHW7oZ4=";
    }
    {
      name = "z02";
      hash = "sha256-sO5MLEjoW6OgeMG9WUiFeZY/Z47Ui7fmw/J24OEb5kg=";
    }
    {
      name = "z03";
      hash = "sha256-HJoiNClkWeKsZAlHQXAJWNB6StPZfEm0XTI6mJllLvM=";
    }
    {
      name = "z04";
      hash = "sha256-CIIXz5EGoxx8AWtVrJd0lOKzfS7rqDS6Wc43C3ifPbA=";
    }
    {
      name = "z05";
      hash = "sha256-zthld1K1yf9Ayy4e80dJHTJI3JCAGyzh3OTksUgaloM=";
    }
    {
      name = "z06";
      hash = "sha256-fqyaw/YDY7FcT5Y3NJYiY7EGbKhZQ6KvjQVZ464zLkk=";
    }
    {
      name = "z07";
      hash = "sha256-NkXevSEoXSG94WDJnNa53hh9l0z5Q/l884cF2E20NAw=";
    }
    {
      name = "z08";
      hash = "sha256-E+0NotIkE2ijdBV5/sY+73ewTieBhtQhh3845TQFdjs=";
    }
    {
      name = "z09";
      hash = "sha256-nzj/BP+4MhNDIUtyW/aqdMqhAcasbNwLHhk8wEzdeog=";
    }
    {
      name = "z10";
      hash = "sha256-633BwoVqSGllX8oElsy1ETVnWO1noGZymUfc6VovSP4=";
    }
    {
      name = "z11";
      hash = "sha256-bRtv6lGYV9CUGOKyAJ5aspZ70R6VkOalA3PVIXZzKo4=";
    }
    {
      name = "z12";
      hash = "sha256-O5sudk+5FsaGva5CcMXtIy+DAMzGCDYL3J296LAYN4o=";
    }
    {
      name = "zip";
      hash = "sha256-xaIE7KfJHcw7eh8y9Kcmsjyr09rWIDkjFON4ec2qI6k=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.29.0";
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
    hash = "sha256-1LdX6x0gGNvAwfD1hVeGF5De87MTwAmlwBxjYuhtkLc=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-tX/roXvfjziWQgUxycQuP3wqk3mf/3kJdUxPtCDh+mw=";

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
