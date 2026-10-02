#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh          # Update blender-mcp to the newest v* tag
#   ./update.sh 1.0.4    # Update blender-mcp to a specific version
#
# The MCP server and the Blender add-on (`passthru.addon`) share one source.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="https://projects.blender.org/lab/blender_mcp.git"

if [[ -n "${1:-}" ]]; then
	VERSION="${1#v}"
	echo "==> Updating blender-mcp to specified version ${VERSION}"
else
	echo "==> Fetching latest blender-mcp tag..."
	LATEST_TAG=$(git ls-remote --tags --refs --sort=-v:refname "${REPO}" 'v*' | head -n1 | sed 's#.*refs/tags/##')
	VERSION="${LATEST_TAG#v}"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep -m1 -E '^  version = "' "${DEFAULT_NIX}" | sed 's/.*version = "\([^"]*\)".*/\1/')

if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at blender-mcp ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating blender-mcp from ${CURRENT_VERSION} to ${VERSION}"
echo "==> Computing source hash..."
SRC_HASH="$(nix flake prefetch --json "git+${REPO}?ref=refs/tags/v${VERSION}" | jq -r '.hash')"
echo "    Source hash: ${SRC_HASH}"

VERSION="${VERSION}" SRC_HASH="${SRC_HASH}" perl -0pi -e '
  s/^  version = "[^"]+";/  version = "$ENV{VERSION}";/m;
  s#(rev = "v\$\{version\}";\n\s+hash = ")[^"]+(";)#$1$ENV{SRC_HASH}$2#;
' "${DEFAULT_NIX}"

if ! grep -Fq "  version = \"${VERSION}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: version was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi
if ! grep -Fq "hash = \"${SRC_HASH}\";" "${DEFAULT_NIX}"; then
	echo "ERROR: source hash was not updated in ${DEFAULT_NIX}" >&2
	exit 1
fi

echo "==> Done! blender-mcp ${VERSION}"
echo "Next step: nix build '.#blender-mcp'"
