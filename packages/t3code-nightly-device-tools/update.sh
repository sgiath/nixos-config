#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="pingdotgg/t3code"

# The tool versions are whatever the pinned nightly installs; t3code-nightly's
# update.sh calls this after bumping, so run order does not matter.
T3_VERSION="${1:-$(jq -r '.version' "${SCRIPT_DIR}/../t3code-nightly/sources.json")}"
T3_VERSION="${T3_VERSION#v}"

echo "==> Reading device tool pins from T3 Code ${T3_VERSION}..."
PINS="$(gh api -H "Accept: application/vnd.github.raw" \
	"repos/${REPO}/contents/apps/server/src/device/deviceToolVersions.json?ref=v${T3_VERSION}")"

pin() {
	local version
	version="$(jq -r --arg name "$1" '.[$name] // empty' <<<"${PINS}")"
	if [[ -z "${version}" ]]; then
		echo "ERROR: $1 not found in deviceToolVersions.json at v${T3_VERSION}" >&2
		exit 1
	fi
	echo "${version}"
}

update_tool() {
	local name="$1" version="$2" current
	current="$(jq -r --arg name "${name}" '.packages["node_modules/" + $name].version' "${SCRIPT_DIR}/${name}/package-lock.json")"
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

# Assign before use: a failing `$(pin ...)` passed straight as an argument
# would not stop the script, and npm would then install the latest version.
HUB_VERSION="$(pin expo-device-hub)"
AGENT_VERSION="$(pin agent-device)"
update_tool expo-device-hub "${HUB_VERSION}"
update_tool agent-device "${AGENT_VERSION}"

echo "==> Done"
echo "Next step: nix build '.#t3code-nightly-device-tools'"
