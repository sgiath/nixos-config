#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh          # Update to the latest release shipping the deb
#   ./update.sh 0.1.5    # Update to a specific version
#
# default.nix fetches the Debian revision "-1" asset; a release without it
# fails here instead of at build time.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="devdotfast/whiteboard"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating whiteboard to specified version ${VERSION}"
else
	echo "==> Fetching latest ${REPO} release with a Debian package..."
	# releases/latest can be a platform-only release (v0.3.2 is Windows-only)
	# or an unrelated tag (diffr/*); take the newest release shipping the deb.
	# shellcheck disable=SC2016 # $v is a jq variable
	RELEASES="$(gh api "repos/${REPO}/releases?per_page=100" --paginate --jq '
		.[]
		| select(.draft == false and .prerelease == false and (.tag_name | startswith("v")))
		| (.tag_name | ltrimstr("v")) as $v
		| select(any(.assets[]; .name == "whiteboard_\($v)-1_amd64.deb"))
		| $v
	')"
	VERSION="${RELEASES%%$'\n'*}"
	if [[ -z "${VERSION}" ]]; then
		echo "ERROR: no ${REPO} release ships whiteboard_<version>-1_amd64.deb" >&2
		exit 1
	fi
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

ASSET="whiteboard_${VERSION}-1_amd64.deb"
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

echo "==> Done! Updated whiteboard to ${VERSION}"
echo "Next step: nix build '.#whiteboard'"
