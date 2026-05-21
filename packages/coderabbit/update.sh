#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
BASE_URL="https://cli.coderabbit.ai/releases"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating coderabbit to specified version ${VERSION}"
else
	echo "==> Fetching latest coderabbit version from ${BASE_URL}/latest/VERSION..."
	VERSION="$(curl -fsSL "${BASE_URL}/latest/VERSION" | tr -d '[:space:]')"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Prefetching linux x64 archive..."
HASH_B32="$(nix-prefetch-url "${BASE_URL}/${VERSION}/coderabbit-linux-x64.zip" 2>/dev/null)"
HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")"
echo "    Archive hash: ${HASH_SRI}"

echo "==> Updating default.nix..."
VERSION="${VERSION}" HASH_SRI="${HASH_SRI}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/hash = "sha256-[^"]+";/hash = "$ENV{HASH_SRI}";/;
' "${DEFAULT_NIX}"

echo "==> Done! Updated coderabbit to ${VERSION}"
echo "Next step: nix build '.#coderabbit'"
