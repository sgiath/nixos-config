#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh         # Update to latest version
#   ./update.sh 0.0.4   # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
ASSET_PREFIX="T3-Code"
ASSET_SUFFIX="x86_64.AppImage"

if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Fetching T3 Code release v${VERSION} from GitHub..."
	RELEASE_JSON="$(gh api "repos/pingdotgg/t3code/releases/tags/v${VERSION}")"
else
	echo "==> Fetching latest T3 Code version from GitHub..."
	RELEASE_JSON="$(gh api repos/pingdotgg/t3code/releases/latest)"
	VERSION="$(jq -r '.tag_name | ltrimstr("v")' <<<"${RELEASE_JSON}")"
fi

echo "    Latest version: ${VERSION}"

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

ASSET_NAME="${ASSET_PREFIX}-${VERSION}-${ASSET_SUFFIX}"
DIGEST="$(jq -r --arg asset_name "${ASSET_NAME}" '.assets[] | select(.name == $asset_name) | .digest' <<<"${RELEASE_JSON}")"

if [[ -z "${DIGEST}" || "${DIGEST}" == "null" ]]; then
	echo "ERROR: Could not find digest for asset ${ASSET_NAME}" >&2
	exit 1
fi

HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${DIGEST#sha256:}")"
echo "    Hash: ${HASH_SRI}"

echo "==> Updating default.nix..."
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"${HASH_SRI}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated T3 Code to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#t3code'"
echo "  2. Commit changes"
