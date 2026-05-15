#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh        # Update to latest version
#   ./update.sh 0.30.0 # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
PACKAGE="@runfusion/fusion"

if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating fusion to specified version ${VERSION}"
else
	echo "==> Fetching latest fusion version from npm..."
	VERSION="$(npm view "${PACKAGE}" version 2>/dev/null)"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Fetching npm metadata..."
TARBALL_URL="$(npm view "${PACKAGE}@${VERSION}" dist.tarball 2>/dev/null)"
TARBALL_INTEGRITY="$(npm view "${PACKAGE}@${VERSION}" dist.integrity 2>/dev/null)"
echo "    Tarball: ${TARBALL_URL}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Generating package-lock.json..."
pushd "${TMPDIR}" >/dev/null
npm pack "${PACKAGE}@${VERSION}" --silent >/dev/null
tar -xzf runfusion-fusion-*.tgz
pushd package >/dev/null
npm install --package-lock-only --ignore-scripts --legacy-peer-deps --silent
cp package-lock.json "${SCRIPT_DIR}/package-lock.json"
popd >/dev/null
popd >/dev/null

echo "==> Computing npm dependencies hash..."
NPM_DEPS_HASH="$(nix run nixpkgs#prefetch-npm-deps -- "${SCRIPT_DIR}/package-lock.json" 2>/dev/null)"
echo "    npm deps hash: ${NPM_DEPS_HASH}"

echo "==> Updating default.nix..."
perl -0pi -e 's#version = "[^"]+";#version = "'"${VERSION}"'";#' "${DEFAULT_NIX}"
perl -0pi -e 's#hash = "sha[0-9]+-[^"]+";#hash = "'"${TARBALL_INTEGRITY}"'";#' "${DEFAULT_NIX}"
perl -0pi -e 's#npmDepsHash = (lib\.fakeHash|"sha256-[^"]+");#npmDepsHash = "'"${NPM_DEPS_HASH}"'";#' "${DEFAULT_NIX}"

echo "==> Done! Updated fusion to ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#fusion'"
echo "  2. Commit changes"
