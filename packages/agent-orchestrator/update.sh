#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh          # Update to the latest stable release
#   ./update.sh 0.13.0   # Update to a specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="Untrivial-ai/agent-orchestrator"
ASSET="agent-orchestrator-linux-x64.deb"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating agent-orchestrator to specified version ${VERSION}"
else
	echo "==> Fetching latest ${REPO} release..."
	VERSION="$(gh api "repos/${REPO}/releases/latest" --jq '.tag_name | ltrimstr("v")')"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

if ! gh api "repos/${REPO}/releases/tags/v${VERSION}" --jq '.assets[].name' | grep -Fxq "${ASSET}"; then
	echo "ERROR: release v${VERSION} does not ship ${ASSET}" >&2
	exit 1
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ASSET}"
echo "==> Computing source hash for ${URL}..."
HASH="$(nix store prefetch-file --json "${URL}" | jq -r '.hash')"
echo "    Source hash: ${HASH}"

echo "==> Updating default.nix..."
VERSION="${VERSION}" HASH="${HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/hash = "[^"]+";/hash = "$ENV{HASH}";/;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated agent-orchestrator to ${VERSION}"
echo "Next step: nix build '.#agent-orchestrator'"
