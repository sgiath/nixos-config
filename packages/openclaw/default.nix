{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
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
    # Add missing dependency for matrix extension (upstream issue)
    ${lib.getExe jq} '.dependencies["@vector-im/matrix-bot-sdk"] = "^0.8.0-element.3"' package.json > package.json.new
    mv package.json.new package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-qm8f52gD+Ad6ZsPIqPyxelJ6Svl2OODQIkv04aSxB/k=";

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
