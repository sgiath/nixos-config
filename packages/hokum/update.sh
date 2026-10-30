#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update to latest version
#   ./update.sh 0.1.4     # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating hokum to specified version ${VERSION}"
else
	echo "==> Fetching latest hokum version from GitHub..."
	LATEST_TAG=$(gh api repos/anomalyco/hokum/releases/latest --jq '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep -m1 'version = "' "${DEFAULT_NIX}" | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

echo "==> Computing source hash..."
SRC_JSON="$(nix flake prefetch --json "github:anomalyco/hokum/v${VERSION}")"
SRC_HASH="$(jq -r '.hash' <<<"${SRC_JSON}")"
echo "    Source hash: ${SRC_HASH}"

# The cargo vendor hash comes from building this flake's own cargoDeps with a
# placeholder hash; any failure puts the previous default.nix back.
BACKUP="$(mktemp)"
cp "${DEFAULT_NIX}" "${BACKUP}"
restore() {
	if [[ -n "${BACKUP}" ]]; then
		cp "${BACKUP}" "${DEFAULT_NIX}"
		rm -f "${BACKUP}"
	fi
}
trap restore EXIT

VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s#(repo = "hokum";\n\s+rev = "v\$\{version\}";\n\s+hash = ")[^"]+(";)#$1$ENV{SRC_HASH}$2#;
  s#cargoHash = "[^"]+";#cargoHash = lib.fakeHash;#;
' "${DEFAULT_NIX}"

echo "==> Computing cargo vendor hash..."
BUILD_OUTPUT="$(nix build --no-link "${REPO_ROOT}#hokum.cargoDeps" 2>&1 || true)"
CARGO_HASH="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' <<<"${BUILD_OUTPUT}" | tail -1 || true)"
if [[ -z "${CARGO_HASH}" ]]; then
	echo "ERROR: Could not determine cargo vendor hash" >&2
	echo "Build output:"
	echo "${BUILD_OUTPUT}"
	exit 1
fi
echo "    Cargo hash: ${CARGO_HASH}"

CARGO_HASH="${CARGO_HASH}" perl -0pi -e '
  s#cargoHash = lib\.fakeHash;#cargoHash = "$ENV{CARGO_HASH}";#;
' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "cargoHash = \"${CARGO_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: cargo hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

rm -f "${BACKUP}"
BACKUP=""

echo "==> Done! Updated hokum to version ${VERSION}"
echo "Next step: nix build '.#hokum'"
