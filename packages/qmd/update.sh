#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
PACKAGE="@tobilu/qmd"

if [[ -n "${1:-}" ]]; then
	VERSION="$1"
else
	echo "==> Fetching latest qmd version from npm..."
	VERSION="$(npm view "${PACKAGE}" version 2>/dev/null)"
fi

echo "    Latest version: ${VERSION}"

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Fetching @tobilu/qmd ${VERSION} metadata..."
TARBALL_URL="$(npm view "${PACKAGE}@${VERSION}" dist.tarball 2>/dev/null)"
TARBALL_INTEGRITY="$(npm view "${PACKAGE}@${VERSION}" dist.integrity 2>/dev/null)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

pushd "${TMPDIR}" >/dev/null
npm pack "${PACKAGE}@${VERSION}" --silent >/dev/null
tar -xzf tobi*.tgz
pushd package >/dev/null
npm install --package-lock-only --ignore-scripts --legacy-peer-deps --silent
cp package-lock.json "${SCRIPT_DIR}/package-lock.json"
popd >/dev/null
popd >/dev/null

NPM_DEPS_HASH="$(nix run nixpkgs#prefetch-npm-deps -- "${SCRIPT_DIR}/package-lock.json" 2>/dev/null)"

perl -0pi -e 's#version = "[^"]+";#version = "'"${VERSION}"'";#' "${DEFAULT_NIX}"
perl -0pi -e 's#hash = "sha[0-9]+-[^"]+";#hash = "'"${TARBALL_INTEGRITY}"'";#' "${DEFAULT_NIX}"
perl -0pi -e 's#npmDepsHash = (lib\.fakeHash|"sha256-[^"]+");#npmDepsHash = "'"${NPM_DEPS_HASH}"'";#' "${DEFAULT_NIX}"

echo "==> Updated qmd to ${VERSION}"
echo "    tarball: ${TARBALL_URL}"
echo "    npm deps hash: ${NPM_DEPS_HASH}"
