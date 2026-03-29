{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.28";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-/XCaOfXRTAL3c/N+GKq8D1GAw3N7Jvce+pCwba/D7cI=";
  };

  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };

  sourceRoot = "package";

  postPatch = ''
    if ! ${lib.getExe jq} -e '.dependencies["matrix-js-sdk"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["matrix-js-sdk"] = "^38.2.0"' package.json > package.json.new
      mv package.json.new package.json
    fi

    if ! ${lib.getExe jq} -e '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"] // .optionalDependencies["@matrix-org/matrix-sdk-crypto-nodejs"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"] = "^0.4.0"' package.json > package.json.new
      mv package.json.new package.json
    fi

    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-K8xIncedcEqtfW8nholXunfmlAKHl/LYtyfhEtBea3A=";

  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  postInstall = ''
    matrixCryptoDest="$out/lib/node_modules/openclaw/node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node"

    mkdir -p "$(dirname "$matrixCryptoDest")"
    cp $matrixCryptoNative "$matrixCryptoDest"

    test -f "$matrixCryptoDest"
  '';

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way.";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
