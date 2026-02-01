#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.10.1    # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
CARGO_LOCK="${SCRIPT_DIR}/Cargo.lock"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
  echo "==> Updating agent-of-empires to specified version ${VERSION}"
else
  echo "==> Fetching latest agent-of-empires version from GitHub..."
  LATEST_TAG=$(curl -s "https://api.github.com/repos/njbrake/agent-of-empires/releases/latest" | jq -r '.tag_name')
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
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- njbrake agent-of-empires --rev "v${VERSION}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

# Step 2: Clone and generate Cargo.lock
echo "==> Generating Cargo.lock..."
git clone --depth 1 --branch "v${VERSION}" https://github.com/njbrake/agent-of-empires.git "${TMPDIR}/src" 2>&1 | grep -v "^Note:" || true
nix-shell -p cargo rustc --run "cd '${TMPDIR}/src' && cargo generate-lockfile" 2>&1 | tail -1
cp "${TMPDIR}/src/Cargo.lock" "${CARGO_LOCK}"
echo "    Cargo.lock updated"

# Step 3: Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash (in fetchFromGitHub block)
sed -i "/fetchFromGitHub/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated agent-of-empires to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#agent-of-empires'"
echo "  2. Commit changes"
