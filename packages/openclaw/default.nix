{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.2.2-3";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-oOSGLE5WqDhtfAMBIa4wDHv/Gkt21Piki1REmY0Wnzg=";
  };

  # Prebuilt native binary for matrix-sdk-crypto (skipped by --ignore-scripts)
  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };

  sourceRoot = "package";

  postPatch = ''
    # Add missing dependency for matrix extension (upstream issue)
    ${lib.getExe jq} '.dependencies["@vector-im/matrix-bot-sdk"] = "^0.8.0-element.3"' package.json > package.json.new
    mv package.json.new package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-7O2FemubLjTM1s7S4dcmBqYsBs1Hz5CUtZ32OEBF6uc=";

  dontNpmBuild = true;

  # Skip postinstall scripts that try to compile native code
  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  postInstall = ''
    # Install prebuilt matrix-sdk-crypto native binary
    cp $matrixCryptoNative $out/lib/node_modules/openclaw/node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node
  '';

  meta = {
    description = "WhatsApp gateway CLI (Baileys web) with Pi RPC agent";
    homepage = "https://www.npmjs.com/package/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
