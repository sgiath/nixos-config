{
  lib,
  buildNpmPackage,
  fetchzip,
  fetchurl,
  p7zip,
}:
let
  version = "2.24.1";
  pname = "5etools";

  imgHashes = [
    {
      name = "z01";
      hash = "sha256-fWir9jw0de03Nr7IPgBV74Q00AFibf50zuFLCveGuxo=";
    }
    {
      name = "z02";
      hash = "sha256-B05o/amcw2T/a0XOhiQSia2iK5oPPQRBY7lj+en/eio=";
    }
    {
      name = "z03";
      hash = "sha256-DCEFaGlY7VgHlz9ax6BBDg1ob7Jedg63BbtH0fjsf6Q=";
    }
    {
      name = "z04";
      hash = "sha256-x2yQ352Ybv5Ja2eyzTKUYXGvNB0mrNQH8Gfurr+33SM=";
    }
    {
      name = "z05";
      hash = "sha256-+tmf1NQDFRXv35q/t0rXyEynaORs/VvlD3lmoUQgqg8=";
    }
    {
      name = "z06";
      hash = "sha256-d2aAgNMaApXkmJBQAJL4vb5izQmRAnA+LcZoQrimwqE=";
    }
    {
      name = "z07";
      hash = "sha256-gfJAwQ5pfSF449Cwt7UhpnHbS/7dsJTvqgsvebq2Gmg=";
    }
    {
      name = "z08";
      hash = "sha256-3YSFupQq3M+BEPGL5PnmOXECVjPYQzox9FhfJv7C0wc=";
    }
    {
      name = "z09";
      hash = "sha256-jtYMF8Kf/sjsMn4foeI0Xp9mAJeXbH3K50QEU9LKhyE=";
    }
    {
      name = "z10";
      hash = "sha256-juuMKUKeBv1vH3fbS3mjLJ2TL/vyQRi35m7xeAkE6s4=";
    }
    {
      name = "z11";
      hash = "sha256-o5RUCmgLj+qR/Ypa3GhsrCTiZXgy9CsIOtE8noKODQE=";
    }
    {
      name = "zip";
      hash = "sha256-hAi9uhyW8h7CA5E5Hh1rQ5DEGgc835W/8Ie7P0HTaYo=";
    }
  ];

  copyImgs = lib.lists.forEach imgHashes (
    v:
    let
      img = fetchurl {
        pname = "5etools-img-${v.name}";
        version = "2.22.0";
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
    hash = "sha256-9/97/U9/LGSuAmLgGu8WjlZwlVfnL7VQkc4sB7kGyWQ=";
  };

  # To update: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
  npmDepsHash = "sha256-acw4YRbukp2I4HDXlDzy/ThjERSFMDHw4mK2vdJuoC4=";

  nativeBuildInputs = [ p7zip ];

  preBuild = ''
    # Copy image archives
    ${lib.strings.concatStringsSep "\n" copyImgs}

    # Unpack images (split 7z archive)
    ${p7zip}/bin/7z x -aoa img-v${version}.zip

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
