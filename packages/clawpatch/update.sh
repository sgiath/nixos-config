#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh       # Update to latest GitHub tag
#   ./update.sh 0.3.0 # Update to specific version tag

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating clawpatch to specified version ${VERSION}"
else
	echo "==> Fetching latest clawpatch version from GitHub..."
	VERSION="$(
		git ls-remote --tags --refs --sort='v:refname' https://github.com/openclaw/clawpatch.git 'refs/tags/v*' |
			sed 's#.*refs/tags/v##' |
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
SRC_JSON="$(nix flake prefetch --json "github:openclaw/clawpatch/v${VERSION}")"
SRC_HASH="$(echo "${SRC_JSON}" | jq -r '.hash')"
echo "    Source hash: ${SRC_HASH}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Computing pnpm dependencies hash..."
cat >"${TMPDIR}/pnpm-deps.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.fetchPnpmDeps {
  pname = "clawpatch";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = "clawpatch";
    tag = "v${VERSION}";
    hash = "${SRC_HASH}";
  };
  pnpm = pkgs.pnpm_11;
  fetcherVersion = 3;
  prePnpmInstall = ''
    pnpm config set trust-lockfile true
  '';
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
EOF

BUILD_OUTPUT="$(nix-build "${TMPDIR}/pnpm-deps.nix" 2>&1 || true)"
PNPM_HASH="$(echo "${BUILD_OUTPUT}" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' || true)"
if [[ -z "${PNPM_HASH}" ]]; then
	echo "ERROR: Could not determine pnpm deps hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	exit 1
fi
echo "    pnpm deps hash: ${PNPM_HASH}"

echo "==> Updating default.nix..."
perl -0pi -e 's#version = "[^"]+";#version = "'"${VERSION}"'";#' "${DEFAULT_NIX}"
SRC_HASH="${SRC_HASH}" PNPM_HASH="${PNPM_HASH}" perl -0pi -e '
  s#(src = fetchFromGitHub \{\n(?:(?!  \};)[^\n]*\n)*?    hash = ")[^"]+(";\n  \};)#$1$ENV{SRC_HASH}$2#;
  s#(pnpmDeps = fetchPnpmDeps \{\n(?:(?!  \};)[^\n]*\n)*?    hash = ")[^"]+(";\n  \};)#$1$ENV{PNPM_HASH}$2#;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${PNPM_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: pnpm deps hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated clawpatch to ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#clawpatch'"
echo "  2. Commit changes"
