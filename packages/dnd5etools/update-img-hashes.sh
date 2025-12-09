#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./update-img-hashes.sh 2.10.0
#
# Requires:
#   - nix-prefetch-url
#   - nix (for `nix hash to-sri`)
#
# Notes:
#   - Outputs a complete `imgHashes = [ ... ];` block to imgHashes.nix.
#   - Fetches all files in parallel for faster execution.
#   - You can change NAMES if the set of parts changes.

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "Usage: $0 <version>    e.g. $0 2.12.0" >&2
  exit 1
fi

# All the parts you currently have
NAMES=(z01 z02 z03 z04 z05 z06 z07 z08 z09 z10 z11 zip)

base_url="https://github.com/5etools-mirror-2/5etools-img/releases/download/v${VERSION}"

# Create temp directory for parallel results
TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

# Output file
OUTPUT_FILE="imgHashes.nix"

# Launch all fetches in parallel
for name in "${NAMES[@]}"; do
  (
    url="${base_url}/img-v${VERSION}.${name}"

    # nix-prefetch-url prints the base32 hash to stdout
    # (it also downloads to the store so subsequent builds are fast)
    if ! base32_hash="$(nix-prefetch-url --type sha256 "${url}" 2>/dev/null)"; then
      echo "  # WARNING: failed to prefetch ${name} from ${url}" >&2
      exit 0
    fi

    # Convert nix base32 -> SRI format used by modern Nix fetchers
    sri_hash="$(nix hash convert --hash-algo sha256 --to sri "${base32_hash}")"

    # Write to temp file named after the part
    cat >"${TMPDIR}/${name}.nix" <<EOF
  {
    name = "${name}";
    hash = "${sri_hash}";
  }
EOF
  ) &
done

wait # Wait for all background jobs to complete

# Combine results into output file
echo "imgHashes = [" >"${OUTPUT_FILE}"
for name in "${NAMES[@]}"; do
  [[ -f "${TMPDIR}/${name}.nix" ]] && cat "${TMPDIR}/${name}.nix" >>"${OUTPUT_FILE}"
done
echo "];" >>"${OUTPUT_FILE}"
