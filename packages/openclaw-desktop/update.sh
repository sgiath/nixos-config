#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh            # Update to the newest stable release that ships the .deb
#   ./update.sh 2026.8.2   # Update to a specific version (must ship the .deb)
#
# Not every OpenClaw release publishes the Linux .deb, so the latest release
# tag alone is not a usable target; only releases carrying the asset count.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="openclaw/openclaw"

deb_asset_name() {
	echo "OpenClaw-${1}-amd64.deb"
}

# Prints "<version>" for every stable release whose assets include the deb.
releases_with_deb() {
	gh api --paginate "repos/${REPO}/releases?per_page=100" --jq '
		.[]
		| select((.draft or .prerelease) | not)
		| .tag_name as $tag
		| ($tag | ltrimstr("v")) as $version
		| select(any(.assets[]; .name == "OpenClaw-\($version)-amd64.deb"))
		| $version
	'
}

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating openclaw-desktop to specified version ${VERSION}"
	ASSET="$(deb_asset_name "${VERSION}")"
	if ! gh api "repos/${REPO}/releases/tags/v${VERSION}" --jq '.assets[].name' | grep -Fxq "${ASSET}"; then
		echo "ERROR: release v${VERSION} does not ship ${ASSET}" >&2
		exit 1
	fi
else
	echo "==> Finding newest ${REPO} release that ships the Linux .deb..."
	VERSION="$(releases_with_deb | sort -V | tail -n 1)"
	if [[ -z "${VERSION}" ]]; then
		echo "ERROR: no stable release with an amd64 .deb asset found" >&2
		exit 1
	fi
	echo "    Newest version with .deb: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

URL="https://github.com/${REPO}/releases/download/v${VERSION}/$(deb_asset_name "${VERSION}")"
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

echo "==> Done! Updated openclaw-desktop to ${VERSION}"
echo "Next step: nix build '.#openclaw-desktop'"
