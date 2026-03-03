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

MATRIX_PATCH_FILE="${SCRIPT_DIR}/patches/matrix-plugin-import-path.patch"
MATRIX_SEND_QUEUE_TS="extensions/matrix/src/matrix/send-queue.ts"
PLUGIN_SDK_INDEX_JS="dist/plugin-sdk/index.js"
PLUGIN_SDK_KEYED_QUEUE_JS="dist/plugin-sdk/keyed-async-queue.js"

if [[ ! -f "${MATRIX_PATCH_FILE}" ]]; then
	echo "ERROR: missing patch file ${MATRIX_PATCH_FILE}" >&2
	exit 1
fi

# Add missing dependency that postPatch adds (must match default.nix)
if ! jq -e '.dependencies["@vector-im/matrix-bot-sdk"]' package.json >/dev/null; then
	echo "==> Applying dependency workaround: @vector-im/matrix-bot-sdk"
	jq '.dependencies["@vector-im/matrix-bot-sdk"] = "^0.8.0-element.3"' package.json >package.json.new
	mv package.json.new package.json
else
	echo "==> Upstream already includes @vector-im/matrix-bot-sdk"
fi

if [[ ! -f "${MATRIX_SEND_QUEUE_TS}" ]]; then
	echo "ERROR: expected ${MATRIX_SEND_QUEUE_TS} not found; review matrix import workaround" >&2
	exit 1
fi

if grep -qF 'openclaw/plugin-sdk/keyed-async-queue' "${MATRIX_SEND_QUEUE_TS}"; then
	echo "==> Matrix import workaround is still required"
elif grep -qF 'openclaw/plugin-sdk' "${MATRIX_SEND_QUEUE_TS}"; then
	echo "==> Upstream matrix import is already fixed"
else
	echo "ERROR: unexpected import format in ${MATRIX_SEND_QUEUE_TS}; review matrix workaround" >&2
	exit 1
fi

if [[ ! -f "${PLUGIN_SDK_INDEX_JS}" ]]; then
	echo "ERROR: expected ${PLUGIN_SDK_INDEX_JS} not found; review keyed queue shim workaround" >&2
	exit 1
fi

if [[ -f "${PLUGIN_SDK_KEYED_QUEUE_JS}" ]]; then
	echo "==> Upstream already ships ${PLUGIN_SDK_KEYED_QUEUE_JS}"
else
	echo "==> Upstream is missing ${PLUGIN_SDK_KEYED_QUEUE_JS}; compatibility shim remains required"
fi

npm install --package-lock-only --ignore-scripts
cp package-lock.json "${SCRIPT_DIR}/package-lock.json"

# Compute npmDepsHash
echo "==> Computing npm dependencies hash..."
NPM_DEPS_HASH=$(nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps ${SCRIPT_DIR}/package-lock.json" 2>/dev/null)
echo "    npm deps hash: ${NPM_DEPS_HASH}"

# Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[^\"]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update tarball hash (only first occurrence - src, not matrixCryptoNative)
sed -i "0,/hash = \"sha256-[^\"]*\";/s|hash = \"sha256-[^\"]*\";|hash = \"${HASH_SRI}\";|" "${DEFAULT_NIX}"

# Update npmDepsHash
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"${NPM_DEPS_HASH}\";|" "${DEFAULT_NIX}"

echo "==> Done! Updated openclaw to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#openclaw'"
echo "  2. Commit changes"
