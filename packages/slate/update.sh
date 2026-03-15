#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update.sh         # Update to latest version
#   ./update.sh 1.0.16  # Update to specific version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="${SCRIPT_DIR}/default.nix"

if [[ -n "${1:-}" ]]; then
	VERSION="$1"
	echo "==> Updating slate to specified version ${VERSION}"
else
	echo "==> Fetching latest slate version from npm..."
	VERSION="$(npm view @randomlabs/slate version)"
	echo "    Latest version: ${VERSION}"
fi

CURRENT_VERSION=$(grep 'version = "' "${DEFAULT_NIX}" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
if [[ "${VERSION}" == "${CURRENT_VERSION}" ]]; then
	echo "==> Already at version ${VERSION}, nothing to do"
	exit 0
fi

echo "==> Updating from ${CURRENT_VERSION} to ${VERSION}"

declare -A HASHES=(
	[x86_64-linux]="$(npm view @randomlabs/slate-linux-x64@${VERSION} dist.integrity)"
	[x86_64-linux-musl]="$(npm view @randomlabs/slate-linux-x64-musl@${VERSION} dist.integrity)"
	[aarch64-linux]="$(npm view @randomlabs/slate-linux-arm64@${VERSION} dist.integrity)"
	[aarch64-linux-musl]="$(npm view @randomlabs/slate-linux-arm64-musl@${VERSION} dist.integrity)"
)

for key in "${!HASHES[@]}"; do
	if [[ -z "${HASHES[$key]}" ]]; then
		echo "ERROR: Missing hash for ${key}" >&2
		exit 1
	fi
done

echo "==> Updating default.nix..."
python - "${DEFAULT_NIX}" "${VERSION}" \
	"${HASHES[x86_64-linux]}" \
	"${HASHES[x86_64-linux-musl]}" \
	"${HASHES[aarch64-linux]}" \
	"${HASHES[aarch64-linux-musl]}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
version = sys.argv[2]
replacements = {
    '"x86_64-linux"': sys.argv[3],
    '"x86_64-linux-musl"': sys.argv[4],
    '"aarch64-linux"': sys.argv[5],
    '"aarch64-linux-musl"': sys.argv[6],
}

text = path.read_text()
text = re.sub(r'version = "[^"]+";', f'version = "{version}";', text, count=1)
for key, hash_value in replacements.items():
    pattern = rf'({re.escape(key)}\s*=\s*")([^"]+)(";)' 
    text, count = re.subn(pattern, rf'\1{hash_value}\3', text, count=1)
    if count != 1:
        raise SystemExit(f"failed to update hash for {key}")

path.write_text(text)
PY

echo "==> Done! Updated slate to version ${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Test the build: nix build '.#slate'"
echo "  2. Commit changes"
