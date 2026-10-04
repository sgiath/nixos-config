#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_JSON="${SCRIPT_DIR}/sources.json"
REPO="pingdotgg/t3code"

# The tool versions are whatever the pinned nightly installs; t3code-nightly's
# update.sh calls this after bumping, so run order does not matter.
T3_VERSION="${1:-$(jq -r '.version' "${SCRIPT_DIR}/../t3code-nightly/sources.json")}"
T3_VERSION="${T3_VERSION#v}"

echo "==> Reading device tool pins from T3 Code ${T3_VERSION}..."
TOOLCHAIN="$(gh api -H "Accept: application/vnd.github.raw" \
	"repos/${REPO}/contents/apps/server/src/device/DeviceToolchain.ts?ref=v${T3_VERSION}")"

pin() {
	local version
	version="$(sed -n "s/^export const $1 = \"\\([^\"]*\\)\";\$/\\1/p" <<<"${TOOLCHAIN}")"
	if [[ -z "${version}" ]]; then
		echo "ERROR: $1 not found in DeviceToolchain.ts at v${T3_VERSION}" >&2
		exit 1
	fi
	echo "${version}"
}

locked() {
	jq -r --arg name "$2" '.packages["node_modules/" + $name].version' "${SCRIPT_DIR}/$1/package-lock.json"
}

update_tool() {
	local name="$1" version="$2" current
	current="$(locked "${name}" "${name}")"
	if [[ "${version}" == "${current}" ]]; then
		echo "    ${name} already at ${version}"
		return
	fi
	echo "    ${name}: ${current} -> ${version}"
	(
		cd "${SCRIPT_DIR}/${name}"
		echo '{}' >package.json
		rm -f package-lock.json
		npm install --package-lock-only --ignore-scripts --no-fund --no-audit "${name}@${version}" >/dev/null
	)
}

update_tool expo-device-hub "$(pin DEVICE_HUB_VERSION)"
update_tool agent-device "$(pin AGENT_DEVICE_VERSION)"

DATACHANNEL="$(locked expo-device-hub node-datachannel)"
CURRENT_DATACHANNEL="$(jq -r '."node-datachannel".version' "${SOURCES_JSON}")"
if [[ "${DATACHANNEL}" == "${CURRENT_DATACHANNEL}" ]]; then
	echo "    node-datachannel prebuilt already at ${DATACHANNEL}"
else
	echo "    node-datachannel prebuilt: ${CURRENT_DATACHANNEL} -> ${DATACHANNEL}"
	prebuilt_hash() {
		nix store prefetch-file --json \
			"https://github.com/murat-dogan/node-datachannel/releases/download/v${DATACHANNEL}/node-datachannel-v${DATACHANNEL}-napi-v8-linux-$1.tar.gz" |
			jq -r '.hash'
	}
	X64="$(prebuilt_hash x64)"
	ARM64="$(prebuilt_hash arm64)"
	jq -n --arg version "${DATACHANNEL}" --arg x64 "${X64}" --arg arm64 "${ARM64}" \
		'{ "node-datachannel": { version: $version, "x86_64-linux": $x64, "aarch64-linux": $arm64 } }' \
		>"${SOURCES_JSON}"
fi

echo "==> Done"
echo "Next step: nix build '.#t3code-nightly-device-tools'"
