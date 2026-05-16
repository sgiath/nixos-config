#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh        # Update to latest GitHub tag
#   ./update.sh 0.30.0 # Update to specific version tag

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating fusion to specified version ${VERSION}"
else
	echo "==> Fetching latest fusion version from GitHub..."
	VERSION="$(
		git ls-remote --tags --sort='v:refname' https://github.com/Runfusion/Fusion.git 'refs/tags/v*' |
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
SRC_JSON="$(nix flake prefetch --json "github:Runfusion/Fusion/v${VERSION}")"
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
  pname = "fusion";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "Runfusion";
    repo = "Fusion";
    tag = "v${VERSION}";
    hash = "${SRC_HASH}";
  };
  fetcherVersion = 3;
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
perl -0pi -e 's#(tag = "v\$\{finalAttrs\.version\}";\n    hash = ")[^"]+(";)#$1'"${SRC_HASH}"'$2#' "${DEFAULT_NIX}"
perl -0pi -e 's#(fetcherVersion = 3;\n    hash = ")[^"]+(";)#$1'"${PNPM_HASH}"'$2#' "${DEFAULT_NIX}"

echo "==> Done! Updated fusion to ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#fusion'"
echo "  2. Commit changes"
