{
  lib,
  buildNpmPackage,
  fetchurl,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.23-2";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-a8sfYP0SdypcVb7+kCiKKJxrl/vv3+10TOY+S8qFmO8=";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-E2FMz7fugJw46iK7lHE3kjmwkMc3SBj01zTDo8w8Oc8=";

  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way.";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
