#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO_OWNER="ilyaux"
REPO_NAME="Eve-flipper"

cd "${SCRIPT_DIR}"

if [[ -n "${1:-}" ]]; then
  version="${1#v}"
  echo "==> Updating eve-flipper to specified version ${version}"
else
  echo "==> Fetching latest eve-flipper version from GitHub..."
  latest_tag="$(gh api "repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" --jq '.tag_name')"
  version="${latest_tag#v}"
  echo "    Latest version: ${version}"
fi

current_version="$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')"
if [[ "${version}" == "${current_version}" ]]; then
  echo "==> Already at version ${version}, nothing to do"
  exit 0
fi

echo "==> Updating from ${current_version} to ${version}"

echo "==> Computing source hash..."
src_hash="$(nix-prefetch-github "${REPO_OWNER}" "${REPO_NAME}" --rev "v${version}" | jq -r .hash)"
echo "    Source hash: ${src_hash}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> Computing pnpm dependencies hash..."
cat >"${tmp}/pnpm-deps.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.fetchPnpmDeps {
  pname = "eve-flipper-frontend";
  version = "${version}";
  src = pkgs.fetchFromGitHub {
    owner = "${REPO_OWNER}";
    repo = "${REPO_NAME}";
    rev = "v${version}";
    hash = "${src_hash}";
  };
  sourceRoot = "source/frontend";
  fetcherVersion = 4;
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
EOF
pnpm_output="$(nix-build "${tmp}/pnpm-deps.nix" 2>&1 || true)"
pnpm_hash="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' <<<"${pnpm_output}" | tail -n1 || true)"
if [[ -z "${pnpm_hash}" ]]; then
  echo "ERROR: Could not determine pnpm dependencies hash" >&2
  echo "${pnpm_output}" >&2
  exit 1
fi
echo "    pnpm deps hash: ${pnpm_hash}"

echo "==> Computing Go vendor hash..."
cat >"${tmp}/go-vendor.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.buildGoModule {
  pname = "eve-flipper";
  version = "${version}";
  src = pkgs.fetchFromGitHub {
    owner = "${REPO_OWNER}";
    repo = "${REPO_NAME}";
    rev = "v${version}";
    hash = "${src_hash}";
  };
  vendorHash = pkgs.lib.fakeHash;
}
EOF
vendor_output="$(nix-build "${tmp}/go-vendor.nix" 2>&1 || true)"
vendor_hash="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' <<<"${vendor_output}" | tail -n1 || true)"
if [[ -z "${vendor_hash}" ]]; then
  echo "ERROR: Could not determine Go vendor hash" >&2
  echo "${vendor_output}" >&2
  exit 1
fi
echo "    vendor hash: ${vendor_hash}"

echo "==> Updating default.nix..."
VERSION="${version}" SRC_HASH="${src_hash}" PNPM_HASH="${pnpm_hash}" VENDOR_HASH="${vendor_hash}" \
  perl -0pi -e 's|version = "[^"]*";|version = "$ENV{VERSION}";|g;
    s#(src = fetchFromGitHub \{\n    owner = "ilyaux";\n    repo = "Eve-flipper";\n    rev = "v\$\{version\}";\n    hash = ")[^"]+(";\n  \};)#\1$ENV{SRC_HASH}\2#g;
    s#(fetcherVersion = 4;\n      hash = ")[^"]+(";\n    \};)#\1$ENV{PNPM_HASH}\2#g;
    s|vendorHash = "[^"]*";|vendorHash = "$ENV{VENDOR_HASH}";|g;' \
  "${DEFAULT_NIX}"

echo "==> Done! Updated eve-flipper to version ${version}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#eve-flipper'"
echo "  2. Commit changes"
