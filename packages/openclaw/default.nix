{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

let
  bundledPluginRuntimeDeps = {
    "@aws-sdk/client-s3" = "3.1020.0";
    "@aws-sdk/s3-request-presigner" = "3.1020.0";
    "@lancedb/lancedb" = "^0.27.1";
    "@microsoft/teams.api" = "2.0.6";
    "@microsoft/teams.apps" = "2.0.6";
    "@opentelemetry/api" = "^1.9.1";
    "@opentelemetry/api-logs" = "^0.214.0";
    "@opentelemetry/exporter-logs-otlp-proto" = "^0.214.0";
    "@opentelemetry/exporter-metrics-otlp-proto" = "^0.214.0";
    "@opentelemetry/exporter-trace-otlp-proto" = "^0.214.0";
    "@opentelemetry/resources" = "^2.6.1";
    "@opentelemetry/sdk-logs" = "^0.214.0";
    "@opentelemetry/sdk-metrics" = "^2.6.1";
    "@opentelemetry/sdk-node" = "^0.214.0";
    "@opentelemetry/sdk-trace-base" = "^2.6.1";
    "@opentelemetry/semantic-conventions" = "^1.40.0";
    "@tloncorp/tlon-skill" = "0.3.1";
    "@twurple/api" = "^8.0.3";
    "@twurple/auth" = "^8.0.3";
    "@twurple/chat" = "^8.0.3";
    "@urbit/aura" = "^3.0.0";
    "@whiskeysockets/baileys" = "7.0.0-rc.9";
    acpx = "0.4.0";
    "fake-indexeddb" = "^6.2.5";
    jimp = "^1.6.0";
    "music-metadata" = "^11.12.3";
    "nostr-tools" = "^2.23.3";
    "zca-js" = "2.1.2";
  };
in

buildNpmPackage rec {
  pname = "openclaw";
  version = "2026.4.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
    hash = "sha256-tbXIalz/wOlNcM/3dceVENkF/vDMqrJk/Cse2+1en3A=";
  };

  matrixCryptoNative = fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    hash = "sha256-cHjU3ZhxKPea/RksT2IfZK3s435D8qh1bx0KnwNN5xg=";
  };

  sourceRoot = "package";

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

  npmDepsHash = "sha256-sMKsXo2K/KcW4PJwLTgAFzTAu4QnmAfybBMHGmus6nY=";

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

    # Upstream ships a loader that imports plugin-entry.runtime.ts via JITI, but
    # the file is missing from the published tarball. Recreate a bridge that
    # resolves the current hashed dist chunks at runtime instead of pinning
    # version-specific filenames.
    install -Dm644 /dev/stdin "$packageRoot/dist/plugin-entry.runtime.ts" <<'EOF'
    import type { GatewayRequestHandlerOptions } from "openclaw/plugin-sdk/core";
    import fsSync from "node:fs";
    import path from "node:path";
    import { fileURLToPath, pathToFileURL } from "node:url";

    const distDir = path.dirname(fileURLToPath(import.meta.url));

    type EnsureRuntimeModule = {
      t: (...args: unknown[]) => Promise<void>;
    };

    type VerificationModule = {
      n: (opts?: {
        accountId?: string;
        recoveryKey?: string;
        forceResetCrossSigning?: boolean;
      }) => Promise<{ success: boolean } & Record<string, unknown>>;
      u: (opts?: {
        accountId?: string;
        includeRecoveryKey?: boolean;
      }) => Promise<unknown>;
      v: (
        recoveryKey: string,
        opts?: { accountId?: string }
      ) => Promise<{ success: boolean } & Record<string, unknown>>;
    };

    function resolveChunk(prefix: string, marker: string): string {
      const matches = fsSync
        .readdirSync(distDir)
        .filter((entry) => entry.startsWith(prefix + "-") && entry.endsWith(".js"))
        .sort();

      for (const entry of matches) {
        const fullPath = path.join(distDir, entry);
        if (fsSync.readFileSync(fullPath, "utf8").includes(marker)) {
          return fullPath;
        }
      }

      throw new Error(
        `Unable to resolve ''${prefix} runtime chunk containing ''${marker}; candidates: ''${
          matches.join(", ") || "(none)"
        }`
      );
    }

    let ensureRuntimeModulePromise: Promise<EnsureRuntimeModule> | undefined;
    let verificationModulePromise: Promise<VerificationModule> | undefined;

    async function loadEnsureRuntimeModule(): Promise<EnsureRuntimeModule> {
      ensureRuntimeModulePromise ??= import(
        pathToFileURL(resolveChunk("deps", "ensureMatrixCryptoRuntime")).href
      ) as Promise<EnsureRuntimeModule>;
      return await ensureRuntimeModulePromise;
    }

    async function loadVerificationModule(): Promise<VerificationModule> {
      verificationModulePromise ??= import(
        pathToFileURL(resolveChunk("verification", "bootstrapMatrixVerification")).href
      ) as Promise<VerificationModule>;
      return await verificationModulePromise;
    }

    function sendError(respond: (ok: boolean, payload?: unknown) => void, err: unknown) {
      respond(false, { error: err instanceof Error ? err.message : String(err) });
    }

    export async function ensureMatrixCryptoRuntime(
      ...args: Parameters<EnsureRuntimeModule["t"]>
    ): Promise<void> {
      const { t: ensureRuntime } = await loadEnsureRuntimeModule();
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
        const { v: verifyMatrixRecoveryKey } = await loadVerificationModule();
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
        const { n: bootstrapMatrixVerification } = await loadVerificationModule();
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
        const { u: getMatrixVerificationStatus } = await loadVerificationModule();
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
