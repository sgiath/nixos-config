{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.8";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-cc/cghQcAI2CrNrvGvY4LsQ3afIOAh7SJCnd+IW6aQk=";
  };

  # Prebuilt native binary for matrix-sdk-crypto (skipped by --ignore-scripts)
  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };

  sourceRoot = "package";

  # Temporary compatibility patch for openclaw 2026.3.2 matrix plugin import.
  # Remove once upstream no longer imports:
  #   openclaw/plugin-sdk/keyed-async-queue
  patches = [
    ./patches/matrix-plugin-import-path.patch
  ];

  postPatch = ''
    # Add missing dependency for matrix extension (upstream issue)
    if ! ${lib.getExe jq} -e '.dependencies["@vector-im/matrix-bot-sdk"]' package.json >/dev/null; then
      ${lib.getExe jq} '.dependencies["@vector-im/matrix-bot-sdk"] = "^0.8.0-element.3"' package.json > package.json.new
      mv package.json.new package.json
    fi

    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-LrK2WvsWJnXTyXhlA3OCKSyoeJDHXmXMPj6D453hUas=";

  dontNpmBuild = true;

  # Skip postinstall scripts that try to compile native code
  npmFlags = [ "--ignore-scripts" ];

  makeCacheWritable = true;

  postInstall = ''
    matrixCryptoDest="$out/lib/node_modules/openclaw/node_modules/@matrix-org/matrix-sdk-crypto-nodejs/matrix-sdk-crypto.linux-x64-gnu.node"
    keyedQueueShim="$out/lib/node_modules/openclaw/dist/plugin-sdk/keyed-async-queue.js"

    # Install prebuilt matrix-sdk-crypto native binary
    mkdir -p "$(dirname "$matrixCryptoDest")"
    cp $matrixCryptoNative "$matrixCryptoDest"

    # Temporary compatibility shim for openclaw 2026.3.2 exports mismatch.
    # Remove once upstream ships dist/plugin-sdk/keyed-async-queue.js.
    if [ ! -e "$keyedQueueShim" ]; then
      printf '%s\n' 'export { KeyedAsyncQueue, enqueueKeyedTask } from "./index.js";' > "$keyedQueueShim"
    fi

    # Sanity checks for runtime-critical files.
    test -f "$matrixCryptoDest"
    test -f "$keyedQueueShim"
  '';

  meta = {
    description = "Your own personal AI assistant. Any OS. Any Platform. The lobster way.";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
  };
}
