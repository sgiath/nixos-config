{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-PsmckwA3JcOvs9jDI29/twVGR9FR3Ce54CVuADcvMbc=";
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

    # openclaw 2026.3.2 ships a broken matrix plugin import path
    # that resolves to dist/plugin-sdk/index.js/keyed-async-queue.
    sed -i 's|openclaw/plugin-sdk/keyed-async-queue|openclaw/plugin-sdk|' extensions/matrix/src/matrix/send-queue.ts

    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-Rv7aa8mXG/NSqJcPhLSGxanvVUbfKwReR6m9QoTYLt0=";

  dontNpmBuild = true;

  # Skip postinstall scripts that try to compile native code
  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  postInstall = ''
    # Install prebuilt matrix-sdk-crypto native binary
    cp $matrixCryptoNative $out/lib/node_modules/openclaw/node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node
  '';

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way.";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
