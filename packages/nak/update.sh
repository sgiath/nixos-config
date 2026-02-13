#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.19.0    # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating nak to specified version ${VERSION}"
else
	echo "==> Fetching latest nak version from GitHub..."
	LATEST_TAG=$(curl -s "https://api.github.com/repos/fiatjaf/nak/releases/latest" | jq -r '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

# Compute source hash
echo "==> Prefetching source..."
HASH_B32=$(nix-prefetch-url --unpack "https://github.com/fiatjaf/nak/archive/refs/tags/v${VERSION}.tar.gz" 2>/dev/null)
HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")
echo "    Source hash: ${HASH_SRI}"

# Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"${HASH_SRI}\"|" "${DEFAULT_NIX}"

# Reset vendor hash to trigger rebuild
sed -i 's|vendorHash = "sha256-[^"]*"|vendorHash = lib.fakeHash|' "${DEFAULT_NIX}"

echo "==> Done! Updated nak source to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Build to get new vendorHash: nix build '.#nak' 2>&1 | grep 'got:'"
echo "  2. Update vendorHash in default.nix"
echo "  3. Build again to verify: nix build '.#nak'"
echo "  4. Commit changes"
