#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="schpet/linear-cli"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating linear-cli to specified version ${VERSION}"
else
	echo "==> Fetching latest linear-cli version from GitHub..."
	VERSION="$(
		git ls-remote --tags --sort='v:refname' "https://github.com/${REPO}.git" 'refs/tags/v*' |
			sed 's#.*refs/tags/v##; s#\\^{}##' |
			tail -1
	)"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Computing source hash..."
SRC_JSON="$(nix flake prefetch --json "github:${REPO}/v${VERSION}")"
SRC_HASH="$(jq -r '.hash' <<<"${SRC_JSON}")"
echo "    Source hash: ${SRC_HASH}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

cp "${DEFAULT_NIX}" "${TMPDIR}/default.nix"
VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/(src = fetchFromGitHub \{\n(?:(?!  \};).*\n)*?    hash = ")[^"]+(";\n  \};)/$1$ENV{SRC_HASH}$2/s;
  s/outputHash = "[^"]+";/outputHash = lib.fakeHash;/;
' "${TMPDIR}/default.nix"

cat >"${TMPDIR}/package.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.callPackage ${TMPDIR}/default.nix {}
EOF

echo "==> Computing package output hash..."
BUILD_OUTPUT="$(nix-build "${TMPDIR}/package.nix" 2>&1 || true)"
OUTPUT_HASH="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' <<<"${BUILD_OUTPUT}" | tail -1 || true)"
if [[ -z "${OUTPUT_HASH}" ]]; then
	echo "ERROR: Could not determine package output hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	exit 1
fi
echo "    Output hash: ${OUTPUT_HASH}"

echo "==> Updating default.nix..."
VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" OUTPUT_HASH="${OUTPUT_HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s/(src = fetchFromGitHub \{\n(?:(?!  \};).*\n)*?    hash = ")[^"]+(";\n  \};)/$1$ENV{SRC_HASH}$2/s;
  s/outputHash = "[^"]+";/outputHash = "$ENV{OUTPUT_HASH}";/;
' "${DEFAULT_NIX}"

echo "==> Done! Updated linear-cli to ${VERSION}"
echo "Next step: nix build '.#linear-cli'"
