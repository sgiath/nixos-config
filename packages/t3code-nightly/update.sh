#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_JSON="${SCRIPT_DIR}/sources.json"
REPO="pingdotgg/t3code"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating t3code-nightly to specified version ${VERSION}"
else
	echo "==> Fetching latest T3 Code nightly from GitHub..."
	VERSION="$(gh release list -R "${REPO}" -L 50 --json tagName \
		--jq '[.[].tagName | select(test("^v[0-9.]+-nightly\\."))][0] // empty')"
	VERSION="${VERSION#v}"
	if [[ -z "${VERSION}" ]]; then
		echo "ERROR: no nightly release among the latest 50 releases" >&2
		exit 1
	fi
	echo "    Latest nightly: ${VERSION}"
fi

CURRENT_VERSION="$(jq -r '.version' "${SOURCES_JSON}")"
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

# Both manifests are published with every nightly: SHA256SUMS covers the CLI
# tarballs, the electron-builder feeds carry the AppImage sha512 in base64.
gh release download "v${VERSION}" -R "${REPO}" -D "${TMPDIR}" \
	-p SHA256SUMS -p nightly-linux.yml -p nightly-linux-arm64.yml

cli_hash() {
	local hex
	hex="$(awk -v f="t3-${VERSION}-$1.tar.gz" '$2 == f { print $1 }' "${TMPDIR}/SHA256SUMS")"
	if [[ -z "${hex}" ]]; then
		echo "ERROR: t3-${VERSION}-$1.tar.gz missing from SHA256SUMS" >&2
		exit 1
	fi
	nix hash convert --hash-algo sha256 --to sri "${hex}"
}

appimage_hash() {
	local b64
	b64="$(python3 -c '
import sys, yaml
feed = yaml.safe_load(open(sys.argv[1]))
print(next(f["sha512"] for f in feed["files"] if f["url"] == sys.argv[2]))
' "${TMPDIR}/$1" "T3-Code-${VERSION}-$2.AppImage")"
	echo "sha512-${b64}"
}

X64_CLI="$(cli_hash linux-x64)"
ARM64_CLI="$(cli_hash linux-arm64)"
X64_APPIMAGE="$(appimage_hash nightly-linux.yml x86_64)"
ARM64_APPIMAGE="$(appimage_hash nightly-linux-arm64.yml arm64)"

jq -n \
	--arg version "${VERSION}" \
	--arg x64Cli "${X64_CLI}" \
	--arg x64AppImage "${X64_APPIMAGE}" \
	--arg arm64Cli "${ARM64_CLI}" \
	--arg arm64AppImage "${ARM64_APPIMAGE}" \
	'{
		version: $version,
		"x86_64-linux": { cli: $x64Cli, appimage: $x64AppImage },
		"aarch64-linux": { cli: $arm64Cli, appimage: $arm64AppImage }
	}' >"${SOURCES_JSON}"

"${SCRIPT_DIR}/../t3code-nightly-device-tools/update.sh" "${VERSION}"

echo "==> Done! Updated t3code-nightly to ${VERSION}"
echo "Next step: nix build '.#t3code-nightly' '.#t3code-nightly-desktop' '.#t3code-nightly-device-tools'"
