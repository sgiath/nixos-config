#!/usr/bin/env bash
# Render a self-contained Nebula config for Mobile Nebula ("Add site > From
# file") for a peer listed in modules/nixos/common/nebula.nix. Signs the peer
# (group "mobile") on first use; later runs reuse the stored cert/key.
#
# Usage: scripts/nebula-mobile.sh <peer> [out-file]
# Example: scripts/nebula-mobile.sh phone
#
# The output embeds the private key; it defaults to $XDG_RUNTIME_DIR (tmpfs).
# Move it to the phone, import it, then delete it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOSTS_FILE="${REPO_DIR}/secrets/nebula.yaml"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <peer> [out-file]" >&2
  exit 1
fi
peer="$1"
out="${2:-${XDG_RUNTIME_DIR:-/tmp}/nebula-${peer}.yml}"

for cmd in sops jq nix; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: ${cmd} not found; run inside 'nix develop'" >&2
    exit 1
  fi
done

# Single source of truth for addresses and the lighthouse name.
nebula_opts="$(nix eval --json "${REPO_DIR}#nixosConfigurations.vesta.config.sgiath.nebula")"
domain="$(jq -r .domain <<<"${nebula_opts}")"
ip4="$(jq -r --arg p "${peer}" '.peers[$p].ip4 // empty' <<<"${nebula_opts}")"
ip6="$(jq -r --arg p "${peer}" '.peers[$p].ip6 // empty' <<<"${nebula_opts}")"
lh4="$(jq -r .peers.vesta.ip4 <<<"${nebula_opts}")"
lh6="$(jq -r .peers.vesta.ip6 <<<"${nebula_opts}")"
if [[ -z "${ip4}" || -z "${ip6}" ]]; then
  echo "error: '${peer}' is not in the peers table of modules/nixos/common/nebula.nix" >&2
  exit 1
fi

if ! sops -d --extract "[\"${peer}_cert\"]" "${HOSTS_FILE}" >/dev/null 2>&1; then
  "${SCRIPT_DIR}/nebula-sign.sh" "${peer}" "${ip4}" "${ip6}" mobile
fi

indent() { sed 's/^/    /'; }
ca="$(sops -d --extract '["ca_crt"]' "${HOSTS_FILE}" | indent)"
cert="$(sops -d --extract "[\"${peer}_cert\"]" "${HOSTS_FILE}" | indent)"
key="$(sops -d --extract "[\"${peer}_key\"]" "${HOSTS_FILE}" | indent)"

umask 077
cat >"${out}" <<EOF
# Mobile Nebula site for ${peer} (${ip4}, ${ip6}); mirrors modules/nixos/common/nebula.nix.
pki:
  ca: |
${ca}
  cert: |
${cert}
  key: |
${key}

static_host_map:
  "${lh4}": ["${domain}:4242"]
  "${lh6}": ["${domain}:4242"]

lighthouse:
  am_lighthouse: false
  hosts:
    - "${lh4}"
    - "${lh6}"

relay:
  am_relay: false
  use_relays: true
  relays:
    - "${lh4}"
    - "${lh6}"

punchy:
  punch: true
  respond: true

# Every peer holds a certificate signed by our CA; that is the auth.
firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: any
      host: any

# Resolve through Pi-hole on vesta over the tunnel (ad blocking + overlay and
# LAN names anywhere). Drop this block to keep the phone's system DNS.
mobile_nebula:
  dns_resolvers:
    - "${lh4}"
    - "${lh6}"
  search_domains:
    - "${domain}"
EOF

echo "==> Wrote ${out}"
echo "    Import in Mobile Nebula: Add site > From file. Delete the file afterwards; it contains the private key."
