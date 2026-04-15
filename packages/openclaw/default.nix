{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

let
  bundledPluginRuntimeDeps = builtins.fromJSON (builtins.readFile ./bundled-plugin-runtime-deps.json);
in

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.4.14";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-t7ZB1OS9+p3Lb7qTTUUulj6jxtMSjc2M1GoJKnTDPLo=";
  };

  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };

  sourceRoot = "package";
  patches = [ ./patches/plugin-entry-runtime.patch ];

  postPatch = ''
    ${lib.getExe jq} \
      --argjson bundledPluginRuntimeDeps '${builtins.toJSON bundledPluginRuntimeDeps}' \
      '
        .dependencies = ($bundledPluginRuntimeDeps + (.dependencies // {}))
      ' package.json > package.json.new
    mv package.json.new package.json

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

  npmDepsHash = "sha256-A4MwuQqAFPw48r1qbEKOHn/8nwGFG4+xn0JPxjSXj5k=";

  dontNpmBuild = true;

  npmFlags = [
    "--ignore-scripts"
    "--legacy-peer-deps"
  ];

  makeCacheWritable = true;

  postInstall = ''
    packageRoot="$out/lib/node_modules/openclaw"
    rootNodeModules="$packageRoot/node_modules"

    # Upstream relies on a global-install postinstall hook to hoist bundled
    # extension runtime deps into the package root. We skip npm scripts in Nix,
    # so mirror those bundled deps from dist/extensions/*/node_modules here.
    while IFS= read -r manifest; do
      pluginDir="$(dirname "$manifest")"
      depsJson="$(${lib.getExe jq} -c '(.dependencies // {}) + (.optionalDependencies // {})' "$manifest")"

      while IFS= read -r depName; do
        target="$rootNodeModules/$depName"
        source="$pluginDir/node_modules/$depName"

        if [ -e "$target" ] || [ ! -e "$source" ]; then
          continue
        fi

        mkdir -p "$(dirname "$target")"
        ln -s "$source" "$target"
      done < <(printf '%s\n' "$depsJson" | ${lib.getExe jq} -r 'keys[]')
    done < <(find "$packageRoot/dist/extensions" -mindepth 2 -maxdepth 2 -name package.json -print)

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
