#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-$(npm view @tobilu/qmd version 2>/dev/null)}"

echo "==> Fetching @tobilu/qmd ${VERSION} metadata..."
TARBALL_URL="$(npm view "@tobilu/qmd@${VERSION}" dist.tarball 2>/dev/null)"
TARBALL_INTEGRITY="$(npm view "@tobilu/qmd@${VERSION}" dist.integrity 2>/dev/null)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

pushd "${TMPDIR}" >/dev/null
npm pack "@tobilu/qmd@${VERSION}" --silent >/dev/null
tar -xzf tobi*.tgz
pushd package >/dev/null
npm install --package-lock-only --ignore-scripts --legacy-peer-deps --silent
cp package-lock.json "${SCRIPT_DIR}/package-lock.json"
popd >/dev/null
popd >/dev/null

NPM_DEPS_HASH="$(nix run nixpkgs#prefetch-npm-deps -- "${SCRIPT_DIR}/package-lock.json" 2>/dev/null)"

perl -0pi -e 's|version = "[^"]+";|version = "'"${VERSION}"'";|' "${SCRIPT_DIR}/default.nix"
perl -0pi -e 's|hash = "sha[0-9]+-[^"]+";|hash = "'"${TARBALL_INTEGRITY}"'";|' "${SCRIPT_DIR}/default.nix"
perl -0pi -e 's|npmDepsHash = (lib\.fakeHash|"sha256-[^"]+");|npmDepsHash = "'"${NPM_DEPS_HASH}"'";|' "${SCRIPT_DIR}/default.nix"

echo "==> Updated qmd to ${VERSION}"
echo "    tarball: ${TARBALL_URL}"
echo "    npm deps hash: ${NPM_DEPS_HASH}"
