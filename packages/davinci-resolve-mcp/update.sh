#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"
REPO="samuelgursky/davinci-resolve-mcp"

VERSION="${1:-$(curl --fail --silent --show-error --max-time 30 \
	"https://api.github.com/repos/${REPO}/releases/latest" | jq -er '.tag_name')}"
VERSION="${VERSION#v}"
CURRENT_VERSION=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "${DEFAULT_NIX}")
if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
	printf 'Already at davinci-resolve-mcp %s\n' "$VERSION"
	exit 0
fi

printf 'Updating davinci-resolve-mcp %s -> %s\n' "$CURRENT_VERSION" "$VERSION"
SRC_HASH=$(nix store prefetch-file --unpack --json \
	"https://github.com/${REPO}/archive/refs/tags/v${VERSION}.tar.gz" | jq -er '.hash')
VERSION="$VERSION" SRC_HASH="$SRC_HASH" perl -0pi -e '
  s/^  version = "[^"]+";/  version = "$ENV{VERSION}";/m;
  s/(tag = "v\$\{version\}";\n\s+hash = ")[^"]+(";)/$1$ENV{SRC_HASH}$2/;
' "$DEFAULT_NIX"
printf "Updated davinci-resolve-mcp %s. Validate: nix build '.#davinci-resolve-mcp'\n" "$VERSION"
