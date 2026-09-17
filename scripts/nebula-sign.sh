#!/usr/bin/env bash
# Sign a Nebula host certificate with the CA in secrets/nebula-ca.yaml and
# store the cert/key in secrets/nebula.yaml for modules/nixos/common/nebula.nix.
#
# Usage: scripts/nebula-sign.sh <host> <ipv4> <ipv6> [group,...]
# Example: scripts/nebula-sign.sh juno2 10.42.0.12 fd51:da00:4788::12 compute
#
# Run from `nix develop` (needs sops, nebula-cert, jq) with the sgiath PGP key
# available; the CA private key is only decryptable with it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CA_FILE="${REPO_DIR}/secrets/nebula-ca.yaml"
HOSTS_FILE="${REPO_DIR}/secrets/nebula.yaml"
SUBNET4_BITS=24
SUBNET6_BITS=64

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 <host> <ipv4> <ipv6> [group,...]" >&2
  exit 1
fi
host="$1"
ip4="$2"
ip6="$3"
groups="${4:-}"
networks="${ip4}/${SUBNET4_BITS},${ip6}/${SUBNET6_BITS}"

for cmd in sops nebula-cert jq; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: ${cmd} not found; run inside 'nix develop'" >&2
    exit 1
  fi
done
if [[ ! -f "${CA_FILE}" ]]; then
  echo "error: ${CA_FILE} missing; create the CA first (see AGENTS.md)" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
chmod 700 "${tmp}"

sops -d --extract '["ca_crt"]' "${CA_FILE}" >"${tmp}/ca.crt"
sops -d --extract '["ca_key"]' "${CA_FILE}" >"${tmp}/ca.key"

sign_args=(
  -ca-crt "${tmp}/ca.crt"
  -ca-key "${tmp}/ca.key"
  -name "${host}"
  -networks "${networks}"
  -out-crt "${tmp}/host.crt"
  -out-key "${tmp}/host.key"
)
if [[ -n "${groups}" ]]; then
  sign_args+=(-groups "${groups}")
fi
nebula-cert sign "${sign_args[@]}"

if [[ ! -f "${HOSTS_FILE}" ]]; then
  {
    echo "ca_crt: |"
    sed 's/^/  /' "${tmp}/ca.crt"
  } >"${HOSTS_FILE}"
  sops -e -i "${HOSTS_FILE}"
fi

sops set "${HOSTS_FILE}" "[\"${host}_cert\"]" "$(jq -Rs . <"${tmp}/host.crt")"
sops set "${HOSTS_FILE}" "[\"${host}_key\"]" "$(jq -Rs . <"${tmp}/host.key")"

echo "==> Signed ${host} (${networks}${groups:+, groups: ${groups}})"
echo "    Add '${host} = { ip4 = \"${ip4}\"; ip6 = \"${ip6}\"; };' to peers in modules/nixos/common/nebula.nix if missing."
