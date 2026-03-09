#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.9.0     # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

version_ge() {
	[[ "$1" == "$2" ]] || [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

resolve_go_builder() {
	local required_go_version="$1"
	local current_build_attr="$2"
	local required_major=""
	local required_minor=""
	local builder_names
	local selected_builder=""

	if [[ -z "${required_go_version}" ]]; then
		echo "${current_build_attr}"
		return 0
	fi

	IFS=. read -r required_major required_minor _ <<<"${required_go_version}"

	mapfile -t builder_names < <(
		nix eval --impure --json --expr '
			let pkgs = import <nixpkgs> {};
			in builtins.filter (n: builtins.match "buildGo[0-9]+Module" n != null) (builtins.attrNames pkgs)
		' | jq -r '.[]' | sort
	)

	for builder_name in "${builder_names[@]}"; do
		local digits=""
		local builder_major=""
		local builder_minor=""
		local go_attr=""
		local builder_version=""

		if [[ ! "${builder_name}" =~ ^buildGo([0-9]+)Module$ ]]; then
			continue
		fi

		digits="${BASH_REMATCH[1]}"
		builder_major="${digits:0:1}"
		builder_minor="${digits:1}"

		if (( builder_major < required_major )) || (( builder_major == required_major && builder_minor < required_minor )); then
			continue
		fi

		go_attr="go_${builder_major}_${builder_minor}"
		builder_version=$(nix eval --impure --raw --expr "let pkgs = import <nixpkgs> {}; in pkgs.${go_attr}.version" 2>/dev/null || true)
		if [[ -z "${builder_version}" ]]; then
			continue
		fi

		if version_ge "${builder_version}" "${required_go_version}"; then
			selected_builder="${builder_name}"
			break
		fi
	done

	if [[ -z "${selected_builder}" ]]; then
		echo "ERROR: No buildGo module in nixpkgs satisfies Go ${required_go_version}" >&2
		return 1
	fi

	echo "${selected_builder}"
}

# Get version - either from argument or latest from GitHub
if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating gogcli to specified version ${VERSION}"
else
	echo "==> Fetching latest gogcli version from GitHub..."
	LATEST_TAG=$(curl -s "https://api.github.com/repos/steipete/gogcli/tags" | jq -r '.[0].name')
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

CURRENT_BUILD_ATTR=$(grep -oE 'buildGo[0-9A-Za-z]*Module' "${DEFAULT_NIX}" | head -1)
REQUIRED_GO_VERSION=$(curl -LfsS "https://raw.githubusercontent.com/steipete/gogcli/v${VERSION}/go.mod" | awk '/^go / { print $2; exit }' || true)
BUILD_GO_ATTR=$(resolve_go_builder "${REQUIRED_GO_VERSION}" "${CURRENT_BUILD_ATTR}")
if [[ -n "${REQUIRED_GO_VERSION}" ]]; then
	echo "==> Using ${BUILD_GO_ATTR} for Go ${REQUIRED_GO_VERSION}"
else
	echo "==> Could not determine upstream Go version, keeping ${BUILD_GO_ATTR}"
fi

# Step 1: Compute source hash
echo "==> Computing source hash..."
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- steipete gogcli --rev "v${VERSION}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

# Step 2: Compute vendor hash using fake hash trick
echo "==> Computing vendor hash (this may take a while)..."

cat >"${TMPDIR}/go-vendor.nix" <<EOF
let
  pkgs = import <nixpkgs> {};
in
pkgs.${BUILD_GO_ATTR} rec {
  pname = "gogcli";
  version = "${VERSION}";
  src = pkgs.fetchFromGitHub {
    owner = "steipete";
    repo = "gogcli";
    rev = "v\${version}";
    hash = "${SRC_HASH}";
  };
  vendorHash = pkgs.lib.fakeHash;
  env.CGO_ENABLED = 0;
  subPackages = [ "cmd/gog" ];
}
EOF

# Build with fake hash to get real hash from error
BUILD_OUTPUT=$(nix-build "${TMPDIR}/go-vendor.nix" 2>&1 || true)
VENDOR_HASH=$(echo "${BUILD_OUTPUT}" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' || true)
if [[ -z "${VENDOR_HASH}" ]]; then
	echo "ERROR: Could not determine vendor hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	exit 1
fi
echo "    Vendor hash: ${VENDOR_HASH}"

# Step 3: Update default.nix
echo "==> Updating default.nix..."

# Update buildGo module if needed
if [[ "${CURRENT_BUILD_ATTR}" != "${BUILD_GO_ATTR}" ]]; then
	sed -i "s/${CURRENT_BUILD_ATTR}/${BUILD_GO_ATTR}/g" "${DEFAULT_NIX}"
fi

# Update version
sed -i "s/version = \"[0-9.]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"

# Update source hash (in fetchFromGitHub block)
sed -i "/fetchFromGitHub/,/};/ s|hash = \"sha256-[^\"]*\"|hash = \"${SRC_HASH}\"|" "${DEFAULT_NIX}"

# Update vendorHash
sed -i "s|vendorHash = \"sha256-[^\"]*\"|vendorHash = \"${VENDOR_HASH}\"|" "${DEFAULT_NIX}"

echo "==> Done! Updated gogcli to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#gogcli'"
echo "  2. Commit changes"
