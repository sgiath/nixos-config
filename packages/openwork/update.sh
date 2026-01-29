#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.8.0     # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating openwork to specified version ${VERSION}"
else
	echo "==> Fetching latest openwork version from GitHub..."
	LATEST_TAG=$(curl -s "https://api.github.com/repos/different-ai/openwork/releases/latest" | jq -r '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

# Compute hash for the .deb file
echo "==> Prefetching .deb package..."
DEB_URL="https://github.com/different-ai/openwork/releases/download/v${VERSION}/openwork-desktop-linux-amd64.deb"
HASH_B32=$(nix-prefetch-url "${DEB_URL}" 2>/dev/null)
HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")
echo "    Hash: ${HASH_SRI}"

# Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update hash
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"${HASH_SRI}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated openwork to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#openwork'"
echo "  2. Commit changes"
