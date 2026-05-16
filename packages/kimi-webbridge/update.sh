#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
URL="https://kimi-web-img.moonshot.cn/webbridge/latest/releases/kimi-webbridge-linux-amd64"

echo "==> Fetching latest kimi-webbridge metadata..."
LAST_MODIFIED=$(
  curl -fsSLI "${URL}" |
    awk 'BEGIN { IGNORECASE = 1 } /^last-modified:/ { sub(/\r$/, ""); print substr($0, 16) }'
)

if [[ -z "${LAST_MODIFIED}" ]]; then
  echo "ERROR: could not read Last-Modified header from ${URL}" >&2
  exit 1
fi

VERSION_DATE=$(date -u -d "${LAST_MODIFIED}" +%Y-%m-%d)
VERSION="latest-${VERSION_DATE}"

echo "    Latest version: ${VERSION}"

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
  echo "==> Already at version ${VERSION}, nothing to do"
  exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Prefetching binary..."
HASH_B32=$(nix-prefetch-url "${URL}" 2>/dev/null)
HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")

echo "    Version: ${VERSION}"
echo "    Hash: ${HASH_SRI}"

VERSION="${VERSION}" HASH_SRI="${HASH_SRI}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/hash = "sha256-[^"]+";/hash = "$ENV{HASH_SRI}";/;
' "${DEFAULT_NIX}"

echo "==> Done"
echo "Next step: nix build '.#kimi-webbridge'"
