#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.3.5     # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from CodeRabbit
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
  echo "==> Updating coderabbit to specified version ${VERSION}"
else
  echo "==> Fetching latest coderabbit version..."
  VERSION=$(curl -fsSL "https://cli.coderabbit.ai/releases/latest/VERSION")
  echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
  echo "==> Already at version ${VERSION}, nothing to do"
  exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

# Compute hash for the zip file
echo "==> Computing source hash..."
DOWNLOAD_URL="https://cli.coderabbit.ai/releases/${VERSION}/coderabbit-linux-x64.zip"
SRC_HASH=$(nix-prefetch-url --type sha256 "${DOWNLOAD_URL}" 2>/dev/null | xargs nix hash convert --hash-algo sha256 --to sri)
echo "    Source hash: ${SRC_HASH}"

# Update default.nix
echo "==> Updating default.nix..."
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i "s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated coderabbit to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#coderabbit'"
echo "  2. Commit changes"
