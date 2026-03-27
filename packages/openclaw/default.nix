{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.24";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-5AeWNOBA8PCY6xljNgl1ZFqJVMhxYcUx8MHVKi9fVCk=";
  };

  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };

  matrixCryptoWasmPackage = fetchurl {
    url = "https://registry.npmjs.org/-org/matrix-sdk-crypto-wasm/-/matrix-sdk-crypto-wasm-18.0.0.tgz";
    hash = "sha256-8PSxUdKsY3Z0Nrx2CnB9q0dbkYIm9G68erh5IggOVqU=";
  };

  sourceRoot = "package";

  postPatch = ''
    if ! ${lib.getExe jq} -e '.dependencies["matrix-js-sdk"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["matrix-js-sdk"] = "^38.2.0"' package.json > package.json.new
      mv package.json.new package.json
    fi

    if ! ${lib.getExe jq} -e '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"] = "^0.4.0"' package.json > package.json.new
      mv package.json.new package.json
    fi

    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-dmxiDG6uP+G/uZvdEP+S7/99vfzLbOvehhd28Nzpn7k=";

  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  postInstall = ''
    matrixCryptoDest="$out/lib/node_modules/openclaw/node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node"
    matrixWasmDest="$out/lib/node_modules/openclaw/dist/pkg/matrix_sdk_crypto_wasm_bg.wasm"
    matrixWasmTmp="$(mktemp -d)"

    mkdir -p "$(dirname "$matrixCryptoDest")"
    cp $matrixCryptoNative "$matrixCryptoDest"

    mkdir -p "$(dirname "$matrixWasmDest")"
    tar -xzf $matrixCryptoWasmPackage -C "$matrixWasmTmp" package/pkg/matrix_sdk_crypto_wasm_bg.wasm
    cp "$matrixWasmTmp/package/pkg/matrix_sdk_crypto_wasm_bg.wasm" "$matrixWasmDest"

    test -f "$matrixCryptoDest"
    test -f "$matrixWasmDest"
  '';

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way.";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
