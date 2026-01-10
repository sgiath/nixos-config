#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.13.0    # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
  echo "==> Updating claude-code-acp to specified version ${VERSION}"
else
  echo "==> Fetching latest claude-code-acp version from GitHub..."
  LATEST_TAG=$(curl -s "https://api.github.com/repos/zed-industries/claude-code-acp/releases/latest" | jq -r '.tag_name')
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
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- zed-industries claude-code-acp --rev "v${VERSION}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

# Step 2: Clone repo and compute npm deps hash
echo "==> Computing npm dependencies hash..."
git clone --depth 1 --branch "v${VERSION}" "https://github.com/zed-industries/claude-code-acp.git" "${TMPDIR}/repo" 2>/dev/null

if [[ ! -f "${TMPDIR}/repo/package-lock.json" ]]; then
  echo "ERROR: Could not find package-lock.json" >&2
  exit 1
fi

NPM_DEPS_HASH=$(nix run nixpkgs#prefetch-npm-deps -- "${TMPDIR}/repo/package-lock.json" 2>&1)
echo "    npm deps hash: ${NPM_DEPS_HASH}"

# Step 3: Update default.nix
echo "==> Updating default.nix..."

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash (in fetchFromGitHub block)
sed -i "/fetchFromGitHub/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"

# Update npmDepsHash
sed -i "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"${NPM_DEPS_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated claude-code-acp to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#claude-code-acp'"
echo "  2. Commit changes"
