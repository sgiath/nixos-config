#!/usr/bin/env bash
# Pins the Executor container in modules/nixos/services/executor.nix to the
# newest release tag published in its registry. The tag is looked up in the
# registry rather than on GitHub releases because not every release gets an
# image (1.6.9 has none).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="${SCRIPT_DIR}/../modules/nixos/services/executor.nix"
REPOSITORY="rhyssullivan/executor-selfhost"
DRY_RUN=0

case "${1:-}" in
"") ;;
--dry-run) DRY_RUN=1 ;;
*)
  echo "Usage: $(basename "$0") [--dry-run]" >&2
  exit 1
  ;;
esac

token="$(curl -fsS "https://ghcr.io/token?scope=repository:${REPOSITORY}:pull" | jq -r .token)"

tags=""
next="/v2/${REPOSITORY}/tags/list?n=1000"
while [[ -n "${next}" ]]; do
  headers="$(mktemp)"
  body="$(curl -fsS -D "${headers}" -H "Authorization: Bearer ${token}" "https://ghcr.io${next}")"
  tags+="$(jq -r '.tags[]' <<<"${body}")"$'\n'
  next="$(sed -n 's/^[Ll]ink: <\([^>]*\)>.*/\1/p' "${headers}" | tr -d '\r')"
  rm -f "${headers}"
done

latest="$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' <<<"${tags}" | sort -V | tail -n 1 || true)"
if [[ -z "${latest}" ]]; then
  echo "ERROR: no release tags found for ghcr.io/${REPOSITORY}" >&2
  exit 1
fi

current="$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "${MODULE}")"
if [[ -z "${current}" ]]; then
  echo "ERROR: could not find version in ${MODULE}" >&2
  exit 1
fi

if [[ "${current}" == "${latest}" ]]; then
  echo "==> executor: already at ${current}"
  exit 0
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "==> executor: would update ${current} -> ${latest}"
  exit 0
fi

sed -i "s/^  version = \"${current}\";$/  version = \"${latest}\";/" "${MODULE}"
echo "==> executor: ${current} -> ${latest}"
echo "    Release notes: https://github.com/UsefulSoftwareCo/executor/releases/tag/v${latest}"
