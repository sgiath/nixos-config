#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="backnotprop/plannotator"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating plannotator to specified version ${VERSION}"
else
	echo "==> Fetching latest plannotator version from GitHub..."
	LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

get_sri_hash() {
	local arch="$1"
	local checksum
	checksum=$(curl -fsSL "https://github.com/${REPO}/releases/download/v${VERSION}/plannotator-linux-${arch}.sha256" | cut -d' ' -f1)
	nix hash convert --hash-algo sha256 --to sri "${checksum}"
}

echo "==> Fetching checksums..."
X64_HASH=$(get_sri_hash x64)
ARM64_HASH=$(get_sri_hash arm64)
echo "    x64: ${X64_HASH}"
echo "    arm64: ${ARM64_HASH}"

sed -i "s/version = \"[^"]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i '/arch = "x64";/{n; s|hash = "sha256-[^"]*";|hash = "'"${X64_HASH}"'";|}' "${DEFAULT_NIX}"
sed -i '/arch = "arm64";/{n; s|hash = "sha256-[^"]*";|hash = "'"${ARM64_HASH}"'";|}' "${DEFAULT_NIX}"

echo "==> Done! Build to verify: nix build '.#plannotator'"
