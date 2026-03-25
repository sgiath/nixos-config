#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 2026.2.1  # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from npm
if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating openclaw to specified version ${VERSION}"
else
	echo "==> Fetching latest openclaw version from npm..."
	VERSION=$(npm view openclaw version 2>/dev/null)
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

# Compute hash for the npm tarball
echo "==> Prefetching npm tarball..."
TARBALL_URL="https://registry.npmjs.org/openclaw/-/openclaw-${VERSION}.tgz"
HASH_B32=$(nix-prefetch-url "${TARBALL_URL}" 2>/dev/null)
HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")
echo "    Hash: ${HASH_SRI}"

# Generate package-lock.json
echo "==> Generating package-lock.json..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT
cd "${TEMP_DIR}"
tar -xzf "$(nix-store --realize "$(nix-prefetch-url --print-path "${TARBALL_URL}" 2>/dev/null | tail -1)")"
cd package

if [[ ! -f "dist/extensions/matrix/runtime-api.js" ]]; then
	echo "ERROR: expected dist/extensions/matrix/runtime-api.js not found" >&2
	exit 1
fi

if [[ ! -f "dist/extensions/whatsapp/light-runtime-api.js" ]]; then
	echo "ERROR: expected dist/extensions/whatsapp/light-runtime-api.js not found" >&2
	exit 1
fi

if [[ ! -f "dist/plugin-sdk/keyed-async-queue.js" ]]; then
	echo "ERROR: expected dist/plugin-sdk/keyed-async-queue.js not found" >&2
	exit 1
fi

RUST_CRYPTO_BUNDLE=$(find dist -maxdepth 1 -name 'rust-crypto--*.js' | head -1)
if [[ -z "${RUST_CRYPTO_BUNDLE}" ]]; then
	echo "ERROR: bundled rust crypto chunk not found" >&2
	exit 1
fi

echo "==> Applying package.json compatibility deps"
if ! jq -e '.dependencies["matrix-js-sdk"]' package.json >/dev/null; then
	jq '.dependencies["matrix-js-sdk"] = "^38.2.0"' package.json >package.json.new
	mv package.json.new package.json
fi

if ! jq -e '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"]' package.json >/dev/null; then
	jq '.dependencies["@matrix-org/matrix-sdk-crypto-nodejs"] = "^0.4.0"' package.json >package.json.new
	mv package.json.new package.json
fi

npm install --package-lock-only --ignore-scripts
cp package-lock.json "${SCRIPT_DIR}/package-lock.json"

echo "==> Resolving Matrix native crypto package version..."
MATRIX_NODEJS_VERSION=$(
	node -e '
const lock = require("./package-lock.json");
const pkg = lock.packages?.["node_modules/@matrix-org/matrix-sdk-crypto-nodejs"];
if (!pkg?.version) {
  console.error("matrix-sdk-crypto-nodejs missing from package-lock.json");
  process.exit(1);
}
console.log(pkg.version);
'
)
echo "    matrix-sdk-crypto-nodejs: ${MATRIX_NODEJS_VERSION}"

echo "==> Prefetching Matrix native crypto binary..."
MATRIX_NATIVE_URL="https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v${MATRIX_NODEJS_VERSION}/matrix-sdk-crypto.linux-x64-gnu.node"
MATRIX_NATIVE_HASH_B32=$(nix-prefetch-url "${MATRIX_NATIVE_URL}" 2>/dev/null)
MATRIX_NATIVE_HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${MATRIX_NATIVE_HASH_B32}")
echo "    Native hash: ${MATRIX_NATIVE_HASH_SRI}"

echo "==> Matching bundled rust crypto to a published WASM artifact..."
mapfile -t MATRIX_WASM_INFO < <(
	RUST_CRYPTO_BUNDLE="${RUST_CRYPTO_BUNDLE}" node <<'NODE'
const { execFileSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const bundlePath = process.env.RUST_CRYPTO_BUNDLE;
const bundle = fs.readFileSync(bundlePath, "utf8");
const match = bundle.match(/var matrix_sdk_crypto_wasm_bg_exports = .*?__exportAll\(\{([\s\S]*?)\n\}\);/);
if (!match) {
  console.error(`failed to parse wasm host bindings from ${bundlePath}`);
  process.exit(1);
}

const hostFns = new Set(
  [...match[1].matchAll(/\b(__wbg_[A-Za-z0-9_]+|__wbindgen_[A-Za-z0-9_]+):/g)].map((m) => m[1]),
);

const versions = JSON.parse(execFileSync("npm", ["view", "@matrix-org/matrix-sdk-crypto-wasm", "versions", "--json"], { encoding: "utf8" }));
let best = null;

for (const version of versions.slice().reverse()) {
  const tarballUrl = execFileSync("npm", ["view", `@matrix-org/matrix-sdk-crypto-wasm@${version}`, "dist.tarball"], { encoding: "utf8" }).trim();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `matrix-wasm-${version}-`));
  const tgz = path.join(dir, "pkg.tgz");
  execFileSync("curl", ["-L", "-sS", tarballUrl, "-o", tgz]);
  execFileSync("tar", ["-xzf", tgz, "-C", dir, "package/pkg/matrix_sdk_crypto_wasm_bg.wasm"]);

  const wasmBytes = fs.readFileSync(path.join(dir, "package/pkg/matrix_sdk_crypto_wasm_bg.wasm"));
  const wasmImports = new Set(WebAssembly.Module.imports(new WebAssembly.Module(wasmBytes)).map((i) => i.name));
  const missingInGlue = [...wasmImports].filter((name) => !hostFns.has(name));
  const extraInGlue = [...hostFns].filter((name) => !wasmImports.has(name));

  if (missingInGlue.length === 0 && extraInGlue.every((name) => name === "__wbg_set_wasm")) {
    best = { version, tarballUrl };
    break;
  }
}

if (!best) {
  console.error("no published matrix-sdk-crypto-wasm version matched the bundled rust crypto JS");
  process.exit(1);
}

console.log(best.version);
console.log(best.tarballUrl);
NODE
)

if [[ "${#MATRIX_WASM_INFO[@]}" -ne 2 ]]; then
	echo "ERROR: failed to resolve matching Matrix WASM package" >&2
	exit 1
fi

MATRIX_WASM_VERSION="${MATRIX_WASM_INFO[0]}"
MATRIX_WASM_URL="${MATRIX_WASM_INFO[1]}"
echo "    matrix-sdk-crypto-wasm: ${MATRIX_WASM_VERSION}"

echo "==> Prefetching Matrix WASM package..."
MATRIX_WASM_HASH_B32=$(nix-prefetch-url "${MATRIX_WASM_URL}" 2>/dev/null)
MATRIX_WASM_HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${MATRIX_WASM_HASH_B32}")
echo "    WASM hash: ${MATRIX_WASM_HASH_SRI}"

# Compute npmDepsHash
echo "==> Computing npm dependencies hash..."
NPM_DEPS_HASH=$(nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps ${SCRIPT_DIR}/package-lock.json" 2>/dev/null)
echo "    npm deps hash: ${NPM_DEPS_HASH}"

# Update default.nix
echo "==> Updating default.nix..."

# Update version
perl -0pi -e 's/version = "[^"]*";/version = "'"${VERSION}"'";/' "${DEFAULT_NIX}"

# Update tarball hash (only first occurrence - src, not matrixCryptoNative)
perl -0pi -e 's|(src = fetchurl \{\n\s+url = "https://registry\.npmjs\.org/openclaw/-/openclaw-\$\{version\}\.tgz";\n\s+hash = ")sha256-[^"]*(";\n\s+\};)|${1}'"${HASH_SRI}"'${2}|' "${DEFAULT_NIX}"

# Update native crypto URL/hash
perl -0pi -e 's|(matrixCryptoNative = fetchurl \{\n\s+url = ")[^"]*(";\n\s+hash = ")[^"]*(";\n\s+\};)|${1}'"${MATRIX_NATIVE_URL}"'${2}'"${MATRIX_NATIVE_HASH_SRI}"'${3}|' "${DEFAULT_NIX}"

# Update WASM package URL/hash
perl -0pi -e 's|(matrixCryptoWasmPackage = fetchurl \{\n\s+url = ")[^"]*(";\n\s+hash = ")[^"]*(";\n\s+\};)|${1}'"${MATRIX_WASM_URL}"'${2}'"${MATRIX_WASM_HASH_SRI}"'${3}|' "${DEFAULT_NIX}"

# Update npmDepsHash
perl -0pi -e 's|npmDepsHash = "sha256-[^"]*";|npmDepsHash = "'"${NPM_DEPS_HASH}"'";|' "${DEFAULT_NIX}"

echo "==> Done! Updated openclaw to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#openclaw'"
echo "  2. Commit changes"
