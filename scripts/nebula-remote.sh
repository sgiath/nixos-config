#!/usr/bin/env bash
# Render a self-contained nebula config.yml for a company-administered
# `remote` peer of modules/nixos/common/nebula.nix (the Remote MacBook), run by
# the stock nebula daemon (e.g. Homebrew's, as a launchd daemon). Signs the
# peer (group "remote") on first use; later runs reuse the stored cert/key.
#
# Usage: scripts/nebula-remote.sh <peer> [out-file]
# Example: scripts/nebula-remote.sh mac
#
# The peer accepts only vesta: SSH (herdr.sgiath.dev drives it as a remote PC)
# and T3 Code (proxied as t3-<peer>.sgiath.dev); the NixOS hosts in turn
# accept nothing from it. The output embeds the private key; it defaults to
# $XDG_RUNTIME_DIR (tmpfs). Move it to the peer, install it, then delete it.
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

# Single source of truth for addresses, the remote flag and the lighthouse name.
nebula_opts="$(nix eval --json "${REPO_DIR}#nixosConfigurations.vesta.config.sgiath.nebula")"
domain="$(jq -r .domain <<<"${nebula_opts}")"
ip4="$(jq -r --arg p "${peer}" '.peers[$p].ip4 // empty' <<<"${nebula_opts}")"
ip6="$(jq -r --arg p "${peer}" '.peers[$p].ip6 // empty' <<<"${nebula_opts}")"
remote="$(jq -r --arg p "${peer}" '.peers[$p].remote // false' <<<"${nebula_opts}")"
lh4="$(jq -r .peers.vesta.ip4 <<<"${nebula_opts}")"
lh6="$(jq -r .peers.vesta.ip6 <<<"${nebula_opts}")"
if [[ -z "${ip4}" || -z "${ip6}" ]]; then
  echo "error: '${peer}' is not in the peers table of modules/nixos/common/nebula.nix" >&2
  exit 1
fi
if [[ "${remote}" != true ]]; then
  echo "error: '${peer}' is not marked 'remote = true' in modules/nixos/common/nebula.nix" >&2
  exit 1
fi

if ! sops -d --extract "[\"${peer}_cert\"]" "${HOSTS_FILE}" >/dev/null 2>&1; then
  "${SCRIPT_DIR}/nebula-sign.sh" "${peer}" "${ip4}" "${ip6}" remote
fi

indent() { sed 's/^/    /'; }
ca="$(sops -d --extract '["ca_crt"]' "${HOSTS_FILE}" | indent)"
cert="$(sops -d --extract "[\"${peer}_cert\"]" "${HOSTS_FILE}" | indent)"
key="$(sops -d --extract "[\"${peer}_key\"]" "${HOSTS_FILE}" | indent)"

umask 077
cat >"${out}" <<EOF
# nebula config for the remote peer ${peer} (${ip4}, ${ip6}); mirrors modules/nixos/common/nebula.nix.
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

# Any free port; this peer roams behind NAT and is never dialled directly.
listen:
  host: "[::]"
  port: 0

punchy:
  punch: true
  respond: true

# Outbound is open, but every NixOS host drops what this peer starts; inbound
# is SSH and T3 Code from vesta and nothing else.
firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: 22
      proto: tcp
      host: vesta
    - port: 3773
      proto: tcp
      host: vesta
EOF

echo "==> Wrote ${out}"
echo "    Install it as the nebula daemon's config on ${peer}. Delete the file afterwards; it contains the private key."
