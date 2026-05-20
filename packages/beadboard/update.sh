#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO_URL="https://github.com/jordanhindo/beadboard.git"
OWNER="jordanhindo"
REPO="beadboard"

echo "==> Fetching latest beadboard commit from main..."
REV="$(git ls-remote "${REPO_URL}" refs/heads/main | awk '{ print $1 }')"
if [[ -z "${REV}" ]]; then
	echo "ERROR: Could not resolve refs/heads/main for ${REPO_URL}" >&2
	exit 1
fi
echo "    Latest commit: ${REV}"

VERSION_BASE="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/' | sed 's/-unstable-.*//')"
CURRENT_REV="$(grep 'rev = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*rev = "\([^"]*\)".*/\1/')"
if [[ "${REV}" == "${CURRENT_REV}" ]]; then
	echo "==> Already at commit ${REV}, nothing to do"
	exit 0
fi

COMMIT_DATE="$(git ls-remote --quiet "${REPO_URL}" "${REV}" >/dev/null 2>&1; git show -s --format=%cs "${REV}" 2>/dev/null || true)"
if [[ -z "${COMMIT_DATE}" ]]; then
	TMP_REPO="$(mktemp -d)"
	trap 'rm -rf "${TMP_REPO}"' EXIT
	git -C "${TMP_REPO}" init --quiet
	git -C "${TMP_REPO}" remote add origin "${REPO_URL}"
	git -C "${TMP_REPO}" fetch --quiet --depth 1 origin "${REV}"
	COMMIT_DATE="$(git -C "${TMP_REPO}" show -s --format=%cs FETCH_HEAD)"
fi
VERSION="${VERSION_BASE}-unstable-${COMMIT_DATE}"

echo "==> Updating from ${CURRENT_REV} to ${REV}"
echo "    Version: ${VERSION}"

echo "==> Computing source hash..."
SRC_JSON="$(nix flake prefetch --json "github:${OWNER}/${REPO}/${REV}")"
SRC_HASH="$(echo "${SRC_JSON}" | jq -r '.hash')"
echo "    Source hash: ${SRC_HASH}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Computing npm dependencies hash..."
cat >"${TMPDIR}/npm-deps.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.buildNpmPackage {
  pname = "beadboard";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "${OWNER}";
    repo = "${REPO}";
    rev = "${REV}";
    hash = "${SRC_HASH}";
  };
  nodejs = pkgs.nodejs_22;
  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
EOF

BUILD_OUTPUT="$(nix-build "${TMPDIR}/npm-deps.nix" 2>&1 || true)"
NPM_DEPS_HASH="$(echo "${BUILD_OUTPUT}" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' | tail -1 || true)"
if [[ -z "${NPM_DEPS_HASH}" ]]; then
	echo "ERROR: Could not determine npm deps hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	exit 1
fi
echo "    npm deps hash: ${NPM_DEPS_HASH}"

echo "==> Updating default.nix..."
perl -0pi -e 's#version = "[^"]+";#version = "'"${VERSION}"'";#' "${DEFAULT_NIX}"
perl -0pi -e 's#rev = "[^"]+";#rev = "'"${REV}"'";#' "${DEFAULT_NIX}"
perl -0pi -e 's#(src = fetchFromGitHub \{\n(?:(?!  \};).*\n)*?    hash = ")[^"]+(";\n  \};)#$1'"${SRC_HASH}"'$2#s' "${DEFAULT_NIX}"
perl -0pi -e 's#npmDepsHash = "[^"]+";#npmDepsHash = "'"${NPM_DEPS_HASH}"'";#' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "rev = \"${REV}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: rev was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "npmDepsHash = \"${NPM_DEPS_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: npm deps hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated beadboard to ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#beadboard'"
echo "  2. Commit changes"
