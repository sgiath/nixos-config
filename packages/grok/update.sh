#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
BASE_URL_PRIMARY="https://x.ai/cli"
BASE_URL_FALLBACK="https://storage.googleapis.com/grok-build-public-artifacts/cli"
CHANNEL="${GROK_CHANNEL:-stable}"

download_text() {
	local url="$1"
	curl -fsSL "${url}" 2>/dev/null || true
}

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating grok to specified version ${VERSION}"
else
	echo "==> Fetching latest grok ${CHANNEL} version from ${BASE_URL_PRIMARY}/${CHANNEL}..."
	VERSION="$(download_text "${BASE_URL_PRIMARY}/${CHANNEL}" | tr -d '[:space:]')"
	if [[ -z "${VERSION}" ]]; then
		echo "    Primary unavailable, trying ${BASE_URL_FALLBACK}/${CHANNEL}"
		VERSION="$(download_text "${BASE_URL_FALLBACK}/${CHANNEL}" | tr -d '[:space:]')"
	fi
	if [[ -z "${VERSION}" ]]; then
		echo "ERROR: Could not fetch latest grok version for channel ${CHANNEL}" >&2
		exit 1
	fi
	echo "    Latest version: ${VERSION}"
fi

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[^[:space:]]+)?$ ]]; then
	echo "ERROR: Invalid version format: ${VERSION}" >&2
	exit 1
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Prefetching linux x86_64 binary..."
HASH_B32="$(nix-prefetch-url "${BASE_URL_PRIMARY}/grok-${VERSION}-linux-x86_64" 2>/dev/null || true)"
if [[ -z "${HASH_B32}" ]]; then
	echo "    Primary unavailable, trying fallback artifact host"
	HASH_B32="$(nix-prefetch-url "${BASE_URL_FALLBACK}/grok-${VERSION}-linux-x86_64" 2>/dev/null)"
fi
HASH_SRI="$(nix hash convert --to sri --hash-algo sha256 "${HASH_B32}")"
echo "    Binary hash: ${HASH_SRI}"

echo "==> Updating default.nix..."
VERSION="${VERSION}" HASH_SRI="${HASH_SRI}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/hash = "sha256-[^"]+";/hash = "$ENV{HASH_SRI}";/;
' "${DEFAULT_NIX}"

echo "==> Done! Updated grok to ${VERSION}"
echo "Next step: nix build '.#grok'"
