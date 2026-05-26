#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.19.0    # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating nak to specified version ${VERSION}"
else
	echo "==> Fetching latest nak version from GitHub..."
	LATEST_TAG=$(gh api repos/fiatjaf/nak/releases/latest --jq '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Computing source hash..."
SRC_JSON="$(nix run nixpkgs#nix-prefetch-github -- fiatjaf nak --rev "v${VERSION}" 2>/dev/null)"
SRC_HASH="$(jq -r '.hash' <<<"${SRC_JSON}")"
echo "    Source hash: ${SRC_HASH}"

echo "==> Computing Go vendor hash..."
cat >"${TMPDIR}/go-vendor.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.buildGoModule {
  pname = "nak";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "fiatjaf";
    repo = "nak";
    rev = "v${VERSION}";
    hash = "${SRC_HASH}";
  };
  vendorHash = pkgs.lib.fakeHash;
  subPackages = [ "." ];
}
EOF

BUILD_OUTPUT="$(nix-build "${TMPDIR}/go-vendor.nix" 2>&1 || true)"
VENDOR_HASH="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' <<<"${BUILD_OUTPUT}" | tail -1 || true)"
if [[ -z "${VENDOR_HASH}" ]]; then
	echo "ERROR: Could not determine Go vendor hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	exit 1
fi
echo "    Vendor hash: ${VENDOR_HASH}"

# Update default.nix
echo "==> Updating default.nix..."

VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" VENDOR_HASH="${VENDOR_HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s#(src = fetchFromGitHub \{\n(?:(?!  \};).*\n)*?    hash = ")[^"]+(";\n  \};)#$1$ENV{SRC_HASH}$2#s;
  s#vendorHash = (?:lib\.fakeHash|pkgs\.lib\.fakeHash|"[^"]+");#vendorHash = "$ENV{VENDOR_HASH}";#;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "vendorHash = \"${VENDOR_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: vendor hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if grep -Fq "fakeHash" "${DEFAULT_NIX}"; then
	echo "ERROR: fakeHash remains in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated nak to version ${VERSION}"
echo "Next step: nix build '.#nak'"
