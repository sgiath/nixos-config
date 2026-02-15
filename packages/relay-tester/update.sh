#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh            # Update to latest release
#   ./update.sh 0.2.0      # Update to version
#   ./update.sh v0.2.0     # Update to tag

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
CARGO_LOCK="${SCRIPT_DIR}/Cargo.lock"

if [[ -n "${1:-}" ]]; then
	VERSION_IN="${1}"
	echo "==> Updating relay-tester to specified version ${VERSION_IN}"
else
	echo "==> Fetching latest relay-tester release from GitHub..."
	LATEST_TAG=$(curl -s "https://api.github.com/repos/mikedilger/relay-tester/releases/latest" | jq -r '.tag_name // empty')
	if [[ -z "${LATEST_TAG}" || "${LATEST_TAG}" == "null" ]]; then
		LATEST_TAG=$(curl -s "https://api.github.com/repos/mikedilger/relay-tester/tags" | jq -r '.[0].name')
	fi
	VERSION_IN="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION_IN}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)";/\1/')
if [[ "${VERSION_IN}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION_IN}, nothing to do"
	exit 0
fi

if [[ "${VERSION_IN}" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
	REF="${VERSION_IN}"
elif [[ "${VERSION_IN}" == v* ]]; then
	REF="${VERSION_IN}"
else
	REF="v${VERSION_IN}"
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION_IN} (ref ${REF})"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Computing source hash..."
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- mikedilger relay-tester --rev "${REF}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

echo "==> Regenerating Cargo.lock..."
git clone --depth 1 https://github.com/mikedilger/relay-tester.git "${TMPDIR}/src"
(cd "${TMPDIR}/src" && git checkout "${REF}")
VERSION="${VERSION_IN#v}"

if [[ "${VERSION}" == "${VERSION_IN}" ]]; then
	SRC_VERSION=$(grep '^version =' "${TMPDIR}/src/Cargo.toml" | head -1 | sed -n 's/version = "\([^"]*\)".*/\1/p')
	if [[ -n "${SRC_VERSION}" ]]; then
		VERSION="${SRC_VERSION}"
	fi
fi

nix-shell -p cargo rustc --run "cd '${TMPDIR}/src' && cargo generate-lockfile"
cp "${TMPDIR}/src/Cargo.lock" "${CARGO_LOCK}"

echo "==> Updating default.nix..."
sed -i "s/version = \"[0-9A-Za-z.-]*\";/version = \"${VERSION}\";/" "${DEFAULT_NIX}"
sed -i '/fetchFromGitHub/,/};/ { s|rev = ".*";|rev = "'"'"'${REF}'"'"';|; s|hash = "sha256-.*";|hash = "'"'"'${SRC_HASH}'"'"';|; }' "${DEFAULT_NIX}"

echo "==> Done! Updated relay-tester to version ${VERSION}"
echo
echo "Next steps:"
echo "  1. Run: nix build '.#packages.x86_64-linux.relay-tester'"
echo "  2. If build fails on git dependencies, refresh cargoLock.outputHashes and retry"
