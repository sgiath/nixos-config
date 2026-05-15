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

echo "==> Prefetching binary..."
HASH_B32=$(nix-prefetch-url "${URL}" 2>/dev/null)
HASH_SRI=$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")

echo "    Version: ${VERSION}"
echo "    Hash: ${HASH_SRI}"

perl -0pi -e 's/version = "[^"]+";/version = "'"${VERSION}"'";/' "${DEFAULT_NIX}"
perl -0pi -e 's/hash = "sha256-[^"]+";/hash = "'"${HASH_SRI}"'";/' "${DEFAULT_NIX}"

echo "==> Done"
echo "Next step: nix build '.#kimi-webbridge'"
