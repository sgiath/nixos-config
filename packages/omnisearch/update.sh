#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="omnisearch"
BASE_URL="https://git.bwaaa.monster/${REPO}"

if [[ -n "${1:-}" ]]; then
	REV="$1"
	echo "==> Updating ${REPO} to specified revision ${REV}"
else
	echo "==> Fetching latest ${REPO} revision from ${BASE_URL}..."
	REV="$(git ls-remote "${BASE_URL}" refs/heads/master | cut -f1)"
	echo "    Latest revision: ${REV}"
fi

CURRENT_REV="$(sed -n 's/.*rev = "\([^"]*\)".*/\1/p' "${DEFAULT_NIX}" | head -1)"
if [[ "${REV}" == "${CURRENT_REV}" ]]; then
	echo "==> Already at revision ${REV}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_REV} to ${REV}"

echo "==> Prefetching source..."
HASH_B32="$(nix-prefetch-url --unpack "${BASE_URL}/snapshot/${REPO}-${REV}.tar.gz" 2>/dev/null)"
HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")"
echo "    Source hash: ${HASH_SRI}"

echo "==> Updating default.nix..."
sed -i "s|rev = \"[a-f0-9]*\";|rev = \"${REV}\";|" "${DEFAULT_NIX}"
sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${HASH_SRI}\";|" "${DEFAULT_NIX}"

echo "==> Done! Updated ${REPO} to revision ${REV}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#omnisearch'"
echo "  2. Commit changes"
