#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 1.6.0     # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
  echo "==> Updating ntm to specified version ${VERSION}"
else
  echo "==> Fetching latest ntm version from GitHub..."
  LATEST_TAG=$(curl -s "https://api.github.com/repos/Dicklesworthstone/ntm/releases/latest" | jq -r '.tag_name')
  VERSION="${LATEST_TAG#v}"
  echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
  echo "==> Already at version ${VERSION}, nothing to do"
  exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

# Step 1: Compute source hash
echo "==> Computing source hash..."
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- Dicklesworthstone ntm --rev "v${VERSION}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

# Step 2: Compute vendor hash using fake hash trick
echo "==> Computing vendor hash (this may take a while)..."

cat > "${TMPDIR}/go-vendor.nix" << EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.buildGoModule rec {
  pname = "ntm";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "ntm";
    rev = "v\${version}";
    hash = "${SRC_HASH}";
  };
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  subPackages = [ "cmd/ntm" ];
}
EOF

# Build with fake hash to get real hash from error
BUILD_OUTPUT=$(nix-build "${TMPDIR}/go-vendor.nix" 2>&1 || true)
VENDOR_HASH=$(echo "${BUILD_OUTPUT}" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' || true)
if [[ -z "${VENDOR_HASH}" ]]; then
  echo "ERROR: Could not determine vendor hash" >&2
  echo "Build output:"
  echo "${BUILD_OUTPUT}"
  exit 1
fi
echo "    Vendor hash: ${VENDOR_HASH}"

# Step 3: Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash (in fetchFromGitHub block)
sed -i "/fetchFromGitHub/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"

# Update vendorHash
sed -i "s|vendorHash = \"sha256-[^\"]*\"|vendorHash = \"${VENDOR_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated ntm to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#ntm'"
echo "  2. Commit changes"
