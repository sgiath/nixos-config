{
  lib,
  buildNpmPackage,
  fetchurl,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.2.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-63N/tepPdx7RGzhw/w5y/JeLcj+UQ4L9FseES41p6gM=";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-sv2wTnCT7fjp494P2QzoPdeEJgyOOoVqcTwrsnvAvzQ=";

  dontNpmBuild = true;

  # Skip postinstall scripts that try to compile native code
  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  meta = {
    description = "WhatsApp gateway CLI (Baileys web) with Pi RPC agent";
    homepage = "https://www.npmjs.com/package/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
