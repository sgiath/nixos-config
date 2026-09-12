#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh           # Update KaTrain to the latest GitHub release
#   ./update.sh 1.21.0    # Update KaTrain to a specific version
#
# Also refreshes the vendored pysgf dependency to the latest PyPI release.
# The bundled KataGo binary travels with the KaTrain source, so no separate
# hash is needed for it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating katrain to specified version ${VERSION}"
else
	echo "==> Fetching latest katrain version from GitHub..."
	LATEST_TAG=$(gh api repos/sanderland/katrain/releases/latest --jq '.tag_name')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

echo "==> Fetching latest pysgf version from PyPI..."
PYSGF_JSON="$(curl -fsSL https://pypi.org/pypi/pysgf/json)"
PYSGF_VERSION="$(jq -r '.info.version' <<<"${PYSGF_JSON}")"
echo "    Latest version: ${PYSGF_VERSION}"

# Indentation distinguishes the attrsets: katrain's `version` is top-level in
# the let block (2 spaces), pysgf's is the first 4-space one.
CURRENT_VERSION=$(grep -m1 -E '^  version = "' "${DEFAULT_NIX}" | sed 's/.*version = "\([^"]*\)".*/\1/')
CURRENT_PYSGF_VERSION=$(grep -m1 -E '^    version = "' "${DEFAULT_NIX}" | sed 's/.*version = "\([^"]*\)".*/\1/')

if [[ "${VERSION}" == "${CURRENT_VERSION}" && "${PYSGF_VERSION}" == "${CURRENT_PYSGF_VERSION}" ]]; then
	echo "==> Already at katrain ${VERSION} / pysgf ${PYSGF_VERSION}, nothing to do"
	exit 0
fi

if [[ "${VERSION}" != "${CURRENT_VERSION}" ]]; then
	echo "==> Updating katrain from ${CURRENT_VERSION} to ${VERSION}"
	echo "==> Computing source hash..."
	SRC_HASH="$(nix flake prefetch --json "github:sanderland/katrain/v${VERSION}" | jq -r '.hash')"
	echo "    Source hash: ${SRC_HASH}"

	VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" perl -0pi -e '
	  s/^  version = "[^"]+";/  version = "$ENV{VERSION}";/m;
	  s#(repo = "katrain";\n\s+rev = "v\$\{version\}";\n\s+hash = ")[^"]+(";)#$1$ENV{SRC_HASH}$2#;
	' "${DEFAULT_NIX}"

	if ! grep -Fq "  version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
		echo "ERROR: katrain version was not updated in ${DEFAULT_NIX}" >&2
		exit 1
	fi
	if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
		echo "ERROR: katrain source hash was not updated in ${DEFAULT_NIX}" >&2
		exit 1
	fi
fi

if [[ "${PYSGF_VERSION}" != "${CURRENT_PYSGF_VERSION}" ]]; then
	echo "==> Updating pysgf from ${CURRENT_PYSGF_VERSION} to ${PYSGF_VERSION}"
	PYSGF_SHA256="$(jq -r --arg v "${PYSGF_VERSION}" '.releases[$v][] | select(.packagetype == "sdist") | .digests.sha256' <<<"${PYSGF_JSON}")"
	PYSGF_HASH="$(nix hash convert --hash-algo sha256 --to sri "${PYSGF_SHA256}")"
	echo "    Source hash: ${PYSGF_HASH}"

	PYSGF_VERSION="${PYSGF_VERSION}" PYSGF_HASH="${PYSGF_HASH}" perl -0pi -e '
	  s/^    version = "[^"]+";/    version = "$ENV{PYSGF_VERSION}";/m;
	  s#(inherit pname version;\n\s+hash = ")[^"]+(";)#$1$ENV{PYSGF_HASH}$2#;
	' "${DEFAULT_NIX}"

	if ! grep -Fq "    version = \"${PYSGF_VERSION}\";" "${DEFAULT_NIX}"; then
		echo "ERROR: pysgf version was not updated in ${DEFAULT_NIX}" >&2
		exit 1
	fi
	if ! grep -Fq "hash = \"${PYSGF_HASH}\";" "${DEFAULT_NIX}"; then
		echo "ERROR: pysgf hash was not updated in ${DEFAULT_NIX}" >&2
		exit 1
	fi
fi

echo "==> Done! katrain ${VERSION}, pysgf ${PYSGF_VERSION}"
echo "Next step: nix build '.#katrain'"
