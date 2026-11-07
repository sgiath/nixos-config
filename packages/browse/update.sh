#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="@opencode/browse"

# Assign before use: a failing `$(npm view ...)` passed straight as an argument
# would not stop the script.
if [[ $# -gt 0 ]]; then
	VERSION="$1"
else
	VERSION="$(npm view "${PACKAGE}@latest" version)"
fi
VERSION="${VERSION#v}"

CURRENT="$(jq -r --arg name "${PACKAGE}" '.packages["node_modules/" + $name].version' "${SCRIPT_DIR}/package-lock.json")"
if [[ "${VERSION}" == "${CURRENT}" ]]; then
	echo "browse already at ${VERSION}"
	exit 0
fi

echo "==> browse: ${CURRENT} -> ${VERSION}"
cd "${SCRIPT_DIR}"
echo '{}' >package.json
rm -f package-lock.json
npm install --package-lock-only --ignore-scripts --no-fund --no-audit --save-exact "${PACKAGE}@${VERSION}" >/dev/null

echo "==> Done"
echo "Next step: nix build '.#browse'"
