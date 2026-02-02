#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.9.0     # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating bird to specified version ${VERSION}"
else
	echo "==> Fetching latest bird version from GitHub..."
	LATEST_TAG=$(curl -s "https://api.github.com/repos/steipete/bird/releases/latest" | jq -r '.tag_name')
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
echo "==> Prefetching source tarball..."
SRC_URL="https://github.com/steipete/bird/archive/refs/tags/v${VERSION}.tar.gz"
HASH_B32=$(nix-prefetch-url --unpack "${SRC_URL}" 2>/dev/null)
SRC_HASH=$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")
echo "    Source hash: ${SRC_HASH}"

# Update default.nix - version
echo "==> Updating default.nix..."
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash
sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${SRC_HASH}\";|" "${DEFAULT_NIX}"

# Get pnpm deps hash by building (will fail with correct hash)
echo "==> Computing pnpm deps hash (this may take a moment)..."
cd "${SCRIPT_DIR}/../.."

# Build and capture the hash from the error message
PNPM_HASH=$(nix build ".#bird" 2>&1 | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' || true)

if [[ -n "${PNPM_HASH}" ]]; then
	echo "    pnpm deps hash: ${PNPM_HASH}"
	# Find the line with pnpm deps hash and update it
	sed -i "/pnpmDeps/,/};/s|hash = \"sha256-[^\"]*\"|hash = \"${PNPM_HASH}\"|" "${DEFAULT_NIX}"

	echo "==> Verifying build..."
	if nix build ".#bird" 2>&1; then
		echo "==> Build successful!"
	else
		echo "==> Build failed, please check manually"
		exit 1
	fi
else
	echo "==> Could not determine pnpm deps hash, please update manually"
	exit 1
fi

echo "==> Done! Updated bird to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#bird'"
echo "  2. Commit changes"
