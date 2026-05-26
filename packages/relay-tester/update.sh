#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh            # Update to latest master commit
#   ./update.sh <commit>   # Update to commit
#   ./update.sh <tag>      # Update to tag

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
CARGO_LOCK="${SCRIPT_DIR}/Cargo.lock"
REPO_URL="https://github.com/mikedilger/relay-tester.git"
OWNER="mikedilger"
REPO="relay-tester"
BRANCH="master"

if [[ -n "${1:-}" ]]; then
	VERSION_IN="${1}"
	echo "==> Updating relay-tester to specified version ${VERSION_IN}"
	if [[ "${VERSION_IN}" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
		REF="${VERSION_IN}"
	elif [[ "${VERSION_IN}" == v* ]]; then
		REF="${VERSION_IN}"
	else
		REF="v${VERSION_IN}"
	fi
else
	echo "==> Fetching latest relay-tester commit from ${BRANCH}..."
	REF="$(git ls-remote "${REPO_URL}" "refs/heads/${BRANCH}" | awk '{ print $1 }')"
	if [[ -z "${REF}" ]]; then
		echo "ERROR: Could not resolve refs/heads/${BRANCH} for ${REPO_URL}" >&2
		exit 1
	fi
	VERSION_IN="${REF}"
	echo "    Latest commit: ${REF}"
fi

CURRENT_REV=$(grep 'rev = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*rev = "\([^"]*\)";/\1/')
if [[ "${REF}" == "${CURRENT_REV}" ]]; then
	echo "==> Already at commit ${REF}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_REV} to ${REF}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

echo "==> Computing source hash..."
SRC_JSON=$(nix run nixpkgs#nix-prefetch-github -- "${OWNER}" "${REPO}" --rev "${REF}" 2>/dev/null)
SRC_HASH=$(echo "${SRC_JSON}" | jq -r '.hash')
echo "    Source hash: ${SRC_HASH}"

echo "==> Updating Cargo.lock..."
git -C "${TMPDIR}" clone --no-checkout --depth 1 "${REPO_URL}" src
git -C "${TMPDIR}/src" fetch --depth 1 origin "${REF}"
git -C "${TMPDIR}/src" checkout --detach FETCH_HEAD
VERSION="${VERSION_IN#v}"

if [[ "${VERSION}" == "${VERSION_IN}" ]]; then
	SRC_VERSION=$(grep '^version =' "${TMPDIR}/src/Cargo.toml" | head -1 | sed -n 's/version = "\([^"]*\)".*/\1/p')
	if [[ -n "${SRC_VERSION}" ]]; then
		VERSION="${SRC_VERSION}"
	fi
fi

if [[ ! -f "${TMPDIR}/src/Cargo.lock" ]]; then
	nix-shell -p cargo rustc --run "cd '${TMPDIR}/src' && cargo generate-lockfile"
fi
cp "${TMPDIR}/src/Cargo.lock" "${CARGO_LOCK}"

echo "==> Updating default.nix..."
VERSION="${VERSION}" perl -0pi -e 's#version = "[^"]+";#"version = \"$ENV{VERSION}\";"#e' "${DEFAULT_NIX}"
REF="${REF}" perl -0pi -e 's#(src = fetchFromGitHub \{\n(?:(?!  \};).*\n)*?    rev = ")[^"]+(";)#$1 . $ENV{REF} . $2#es' "${DEFAULT_NIX}"
SRC_HASH="${SRC_HASH}" perl -0pi -e 's#(src = fetchFromGitHub \{\n(?:(?!  \};).*\n)*?    hash = ")[^"]+(";)#$1 . $ENV{SRC_HASH} . $2#es' "${DEFAULT_NIX}"

if ! grep -Fq "version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "rev = \"${REF}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: rev was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! Updated relay-tester to version ${VERSION}"
echo
echo "Next steps:"
echo "  1. Run: nix build '.#relay-tester'"
echo "  2. If build fails on git dependencies, refresh cargoLock.outputHashes and retry"
