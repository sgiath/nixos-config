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
  latest_tag="$(curl -fsSL "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" | jq -r '.tag_name')"
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

echo "==> Downloading source for frontend lockfile..."
curl -fsSL "https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/v${version}.tar.gz" \
  | tar -xz -C "$tmp"

echo "==> Computing npm dependencies hash..."
npm_hash="$(prefetch-npm-deps "$tmp/Eve-flipper-${version}/frontend/package-lock.json")"
echo "    npm deps hash: ${npm_hash}"

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
sed -i \
  -e "s|version = \"[^\"]*\";|version = \"${version}\";|" \
  -e "s|hash = \"sha256-[^\"]*\";|hash = \"${src_hash}\";|" \
  -e "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"${npm_hash}\";|" \
  -e "s|vendorHash = \"sha256-[^\"]*\";|vendorHash = \"${vendor_hash}\";|" \
  "${DEFAULT_NIX}"

echo "==> Done! Updated eve-flipper to version ${version}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#eve-flipper'"
echo "  2. Commit changes"
