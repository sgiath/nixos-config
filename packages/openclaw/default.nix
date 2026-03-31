{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.3.31";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-Y4oU4JbL0ixX538X8b+3BVrP0coDnksD6/TvZdr2KOE=";
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

  npmDepsHash = "sha256-QA/UpcKJn69YrMaiH1Rdsm3dlLanDIGuT6tGLR9PE8w=";

  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

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

    # v2026.3.31 ships a runtime loader that expects this TS shim, but the file
    # is missing from the published tarball. Recreate the tiny bridge against
    # the already-shipped dist chunks.
    install -Dm644 /dev/stdin "$packageRoot/dist/plugin-entry.runtime.ts" <<'EOF'
    import type { GatewayRequestHandlerOptions } from "openclaw/plugin-sdk/core";

    import { t as ensureRuntime } from "./deps-B0cXqav6.js";
    import {
      n as bootstrapMatrixVerification,
      u as getMatrixVerificationStatus,
      v as verifyMatrixRecoveryKey,
    } from "./verification-CNXQrPjz.js";

    function sendError(respond: (ok: boolean, payload?: unknown) => void, err: unknown) {
      respond(false, { error: err instanceof Error ? err.message : String(err) });
    }

    export async function ensureMatrixCryptoRuntime(
      ...args: Parameters<typeof ensureRuntime>
    ): Promise<void> {
      await ensureRuntime(...args);
    }

    export async function handleVerifyRecoveryKey({
      params,
      respond,
    }: GatewayRequestHandlerOptions): Promise<void> {
      try {
        const key = typeof params?.key === "string" ? params.key : "";
        if (!key.trim()) {
          respond(false, { error: "key required" });
          return;
        }

        const accountId =
          typeof params?.accountId === "string" ? params.accountId.trim() || undefined : undefined;
        const result = await verifyMatrixRecoveryKey(key, { accountId });
        respond(result.success, result);
      } catch (err) {
        sendError(respond, err);
      }
    }

    export async function handleVerificationBootstrap({
      params,
      respond,
    }: GatewayRequestHandlerOptions): Promise<void> {
      try {
        const accountId =
          typeof params?.accountId === "string" ? params.accountId.trim() || undefined : undefined;
        const recoveryKey = typeof params?.recoveryKey === "string" ? params.recoveryKey : undefined;
        const forceResetCrossSigning = params?.forceResetCrossSigning === true;
        const result = await bootstrapMatrixVerification({
          accountId,
          recoveryKey,
          forceResetCrossSigning,
        });
        respond(result.success, result);
      } catch (err) {
        sendError(respond, err);
      }
    }

    export async function handleVerificationStatus({
      params,
      respond,
    }: GatewayRequestHandlerOptions): Promise<void> {
      try {
        const accountId =
          typeof params?.accountId === "string" ? params.accountId.trim() || undefined : undefined;
        const includeRecoveryKey = params?.includeRecoveryKey === true;
        const status = await getMatrixVerificationStatus({ accountId, includeRecoveryKey });
        respond(true, status);
      } catch (err) {
        sendError(respond, err);
      }
    }
    EOF

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
