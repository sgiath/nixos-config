#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

# Assign before use: a failing `$(curl ...)` passed straight as an argument
# would not stop the script.
if [[ $# -gt 0 ]]; then
	VERSION="$1"
else
	LATEST="$(curl -fsSL https://registry.npmjs.org/@opencode/browse/latest)"
	VERSION="$(jq -r .version <<<"${LATEST}")"
fi
VERSION="${VERSION#v}"

CURRENT="$(sed -n 's/^  version = "\(.*\)";$/\1/p' "${DEFAULT_NIX}")"
if [[ "${VERSION}" == "${CURRENT}" ]]; then
	echo "browse already at ${VERSION}"
	exit 0
fi

echo "==> browse: ${CURRENT} -> ${VERSION}"

prefetch() {
	local target="$1" url json
	url="https://registry.npmjs.org/@opencode/browse-${target}/-/browse-${target}-${VERSION}.tgz"
	json="$(nix store prefetch-file --json "${url}")"
	jq -r .hash <<<"${json}"
}

# Fetch both before touching default.nix so a missing platform leaves it unchanged.
X86_HASH="$(prefetch linux-x64-musl)"
ARM_HASH="$(prefetch linux-arm64-musl)"

sed -i \
	-e "s|^  version = \".*\";$|  version = \"${VERSION}\";|" \
	-e "/target = \"linux-x64-musl\";/{n;s|hash = \".*\";|hash = \"${X86_HASH}\";|}" \
	-e "/target = \"linux-arm64-musl\";/{n;s|hash = \".*\";|hash = \"${ARM_HASH}\";|}" \
	"${DEFAULT_NIX}"

echo "==> Done"
echo "Next step: nix build '.#browse'"
