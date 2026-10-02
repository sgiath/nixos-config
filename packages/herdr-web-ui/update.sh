#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh          # Update to the newest vX.Y.Z tag
#   ./update.sh 0.3.41   # Update to a specific version
#
# Upstream also tags remote-vX.Y.Z releases for its remote bridge bundle, so
# releases/latest can point at one of those; only plain vX.Y.Z tags count.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
FLAKE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO="devswha/herdr-web-ui"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating herdr-web-ui to specified version ${VERSION}"
else
	echo "==> Fetching newest ${REPO} version tag..."
	VERSION="$(
		gh api --paginate "repos/${REPO}/git/matching-refs/tags/v" --jq '.[].ref | ltrimstr("refs/tags/")' |
			grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
			sort -V |
			tail -1
	)"
	VERSION="${VERSION#v}"
	if [[ -z "${VERSION}" ]]; then
		echo "ERROR: no vX.Y.Z tag found in ${REPO}" >&2
		exit 1
	fi
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Computing source hash..."
SRC_HASH="$(nix flake prefetch --json "github:${REPO}/v${VERSION}" | jq -r '.hash')"
echo "    Source hash: ${SRC_HASH}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT
cp "${DEFAULT_NIX}" "${TMPDIR}/default.nix.orig"
restore() {
	cp "${TMPDIR}/default.nix.orig" "${DEFAULT_NIX}"
	echo "    Restored ${DEFAULT_NIX}" >&2
}

echo "==> Updating default.nix..."
VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s#(src = fetchFromGitHub \{\n(?:(?!  \};)[^\n]*\n)*?    hash = ")[^"]+(";\n  \};)#$1$ENV{SRC_HASH}$2#;
  s#outputHash = "[^"]+";#outputHash = lib.fakeHash;#;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}" ||
	! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}" ||
	! grep -Fq "outputHash = lib.fakeHash;" "${DEFAULT_NIX}"; then
	echo "ERROR: version, source hash or node_modules hash was not updated in ${DEFAULT_NIX}" >&2
	restore
	exit 1
fi

# The fixed-output node_modules hash depends on the bun in this flake's
# nixpkgs, so it is computed by building the package's own node_modules.
echo "==> Computing node_modules hash..."
BUILD_OUTPUT="$(nix build "${FLAKE_DIR}#herdr-web-ui.node_modules" --no-link 2>&1 || true)"
NODE_MODULES_HASH="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' <<<"${BUILD_OUTPUT}" | tail -1 || true)"
if [[ -z "${NODE_MODULES_HASH}" ]]; then
	echo "ERROR: Could not determine node_modules hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	restore
	exit 1
fi
echo "    node_modules hash: ${NODE_MODULES_HASH}"

NODE_MODULES_HASH="${NODE_MODULES_HASH}" perl -0pi -e '
  s#outputHash = lib\.fakeHash;#outputHash = "$ENV{NODE_MODULES_HASH}";#;
' "${DEFAULT_NIX}"

if ! grep -Fq "outputHash = \"${NODE_MODULES_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: node_modules hash was not updated in ${DEFAULT_NIX}" >&2
	restore
	exit 1
fi

echo "==> Validating: nix build '.#herdr-web-ui'"
nix build "${FLAKE_DIR}#herdr-web-ui" --no-link

echo "==> Done! Updated herdr-web-ui to ${VERSION}"
