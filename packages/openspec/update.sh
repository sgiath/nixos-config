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
  echo "==> Updating openspec to specified version ${VERSION}"
else
  echo "==> Fetching latest openspec version from GitHub..."
  LATEST_TAG=$(curl -s "https://api.github.com/repos/Fission-AI/OpenSpec/releases/latest" | jq -r '.tag_name')
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
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- Fission-AI OpenSpec --rev "v${VERSION}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

# Step 2: Compute pnpm deps hash using fake hash trick
echo "==> Computing pnpm dependencies hash (this may take a while)..."

cat > "${TMPDIR}/pnpm-deps.nix" << EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.fetchPnpmDeps {
  pname = "openspec";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    rev = "v${VERSION}";
    hash = "${SRC_HASH}";
  };
  fetcherVersion = 1;
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
EOF

# Build with fake hash to get real hash from error
BUILD_OUTPUT=$(nix-build "${TMPDIR}/pnpm-deps.nix" 2>&1 || true)
PNPM_HASH=$(echo "${BUILD_OUTPUT}" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' || true)
if [[ -z "${PNPM_HASH}" ]]; then
  echo "ERROR: Could not determine pnpm deps hash" >&2
  echo "Build output:"
  echo "${BUILD_OUTPUT}"
  exit 1
fi
echo "    pnpm deps hash: ${PNPM_HASH}"

# Step 3: Update default.nix
echo "==> Updating default.nix..."

# Update version (first occurrence only)
sed -i "0,/version = \"[0-9.]*\";/s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash (line after "rev = ")
sed -i "/rev = /,+1 s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"

# Update pnpm deps hash (line after "fetcherVersion = ")
sed -i "/fetcherVersion = /,+1 s|hash = \"sha256-[^\"]*\"|hash = \"${PNPM_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated openspec to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#openspec'"
echo "  2. Commit changes"
