#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix-prefetch nix-prefetch-github prefetch-npm-deps
set -euo pipefail

cd "$(dirname "$0")"

version="$(curl -fsSL https://api.github.com/repos/ilyaux/Eve-flipper/releases/latest | jq -r '.tag_name | sub("^v"; "")')"
src_hash="$(nix-prefetch-github ilyaux Eve-flipper --rev "v${version}" | jq -r .hash)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://github.com/ilyaux/Eve-flipper/archive/refs/tags/v${version}.tar.gz" \
  | tar -xz -C "$tmp"

npm_hash="$(prefetch-npm-deps "$tmp/Eve-flipper-${version}/frontend/package-lock.json")"
vendor_hash="$(nix-prefetch '{ sha256 }: (import <nixpkgs> {}).buildGoModule {
  pname = "eve-flipper";
  version = "'"${version}"'";
  src = (import <nixpkgs> {}).fetchFromGitHub {
    owner = "ilyaux";
    repo = "Eve-flipper";
    rev = "v'"${version}"'";
    hash = "'"${src_hash}"'";
  };
  vendorHash = sha256;
}' 2>&1 | tail -n1)"

sed -i \
  -e "s|version = \"[^\"]*\";|version = \"${version}\";|" \
  -e "s|hash = \"sha256-[^\"]*\";|hash = \"${src_hash}\";|" \
  -e "0,/npmDepsHash = \"sha256-[^\"]*\";/s//npmDepsHash = \"${npm_hash}\";/" \
  -e "s|vendorHash = \"sha256-[^\"]*\";|vendorHash = \"${vendor_hash}\";|" \
  default.nix
