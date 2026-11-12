#!/usr/bin/env bash
# Install Nebula on a JetKVM over SSH for a peer listed in
# modules/nixos/common/nebula.nix. Signs the peer (group "kvm") on first use;
# later runs reuse the stored cert/key and update the binary and config.
#
# Usage: scripts/nebula-jetkvm.sh <peer> <jetkvm-address>
# Example: scripts/nebula-jetkvm.sh kvm-vesta 192.168.1.248
#
# Needs Developer Mode on the JetKVM with your SSH key (Settings > Advanced).
# Nebula keeps running after Developer Mode is turned off again: the firmware
# starts /userdata/init.d/S??* at boot, and /userdata survives OTA updates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOSTS_FILE="${REPO_DIR}/secrets/nebula.yaml"
# The JetKVMs share Vesta's LAN; reach the lighthouse directly there, like
# Ceres does, and keep the public endpoint as fallback.
VESTA_LAN="192.168.1.2:4242"
HOME_LAN="192.168.1.0/24"
REMOTE_DIR="/userdata/nebula"
INIT_SCRIPT="/userdata/init.d/S23nebula"

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <peer> <jetkvm-address>" >&2
  exit 1
fi
peer="$1"
address="$2"

for cmd in sops jq nix ssh; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "error: ${cmd} not found; run inside 'nix develop'" >&2
    exit 1
  fi
done

ssh_kvm() {
  ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "root@${address}" "$@"
}

echo "==> Checking SSH access to ${address}"
if ! ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "root@${address}" true; then
  echo "error: cannot SSH to root@${address}; turn on Developer Mode and add your SSH key (Settings > Advanced)" >&2
  exit 1
fi

nebula_opts="$(nix eval --json "${REPO_DIR}#nixosConfigurations.vesta.config.sgiath.nebula")"
ip4="$(jq -r --arg p "${peer}" '.peers[$p].ip4 // empty' <<<"${nebula_opts}")"
ip6="$(jq -r --arg p "${peer}" '.peers[$p].ip6 // empty' <<<"${nebula_opts}")"
domain="$(jq -r .domain <<<"${nebula_opts}")"
if [[ -z "${ip4}" || -z "${ip6}" ]]; then
  echo "error: '${peer}' is not in the peers table of modules/nixos/common/nebula.nix" >&2
  exit 1
fi

if ! sops -d --extract "[\"${peer}_cert\"]" "${HOSTS_FILE}" >/dev/null 2>&1; then
  "${SCRIPT_DIR}/nebula-sign.sh" "${peer}" "${ip4}" "${ip6}" kvm
fi

echo "==> Building Nebula for the JetKVM"
nebula_pkg="$(nix build --no-link --print-out-paths "${REPO_DIR}#nebula-jetkvm")"
host_nebula="$(nix build --no-link --print-out-paths "${REPO_DIR}#nixosConfigurations.vesta.pkgs.nebula")"

work="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/nebula-jetkvm.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
umask 077

indent() { sed 's/^/    /'; }
ca="$(sops -d --extract '["ca_crt"]' "${HOSTS_FILE}" | indent)"
cert="$(sops -d --extract "[\"${peer}_cert\"]" "${HOSTS_FILE}" | indent)"
key="$(sops -d --extract "[\"${peer}_key\"]" "${HOSTS_FILE}" | indent)"

# Lighthouses are also the relays; JSON lists are valid YAML.
lighthouses="$(jq -c '[.peers | to_entries[] | select(.value.lighthouse != null)]' <<<"${nebula_opts}")"
static_host_map="$(jq -r --arg lan "${VESTA_LAN}" '.[]
  | ((if .key == "vesta" then [$lan] else [] end) + [.value.lighthouse]) as $endpoints
  | "  \"\(.value.ip4)\": \($endpoints | tojson)\n  \"\(.value.ip6)\": \($endpoints | tojson)"' <<<"${lighthouses}")"
lighthouse_ips="$(jq -c '[.[] | .value.ip4, .value.ip6]' <<<"${lighthouses}")"
# Trusted peers may connect; lighthouses may ping (Hygiea monitors home).
inbound="$(jq -r '.peers | to_entries[]
  | if .value.trusted then "    - port: any\n      proto: any\n      host: \(.key)"
    elif .value.lighthouse != null then "    - port: any\n      proto: icmp\n      host: \(.key)"
    else empty end' <<<"${nebula_opts}")"

cat >"${work}/config.yml" <<EOF
# Nebula on JetKVM ${peer} (${ip4}, ${ip6}); rendered by scripts/nebula-jetkvm.sh
# from modules/nixos/common/nebula.nix. Rerun the script instead of editing.
pki:
  ca: |
${ca}
  cert: |
${cert}
  key: |
${key}

static_host_map:
${static_host_map}

lighthouse:
  am_lighthouse: false
  hosts: ${lighthouse_ips}

relay:
  am_relay: false
  use_relays: true
  relays: ${lighthouse_ips}

listen:
  host: 0.0.0.0
  port: 0

punchy:
  punch: true
  respond: true

preferred_ranges: ["${HOME_LAN}"]

tun:
  dev: nebula1

logging:
  level: warning

# Only trusted peers open connections to the KVM (lighthouses may ping it);
# it opens none of its own.
firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
${inbound}
EOF

echo "==> Validating the config"
"${host_nebula}/bin/nebula" -test -config "${work}/config.yml"

# The JetKVM has no battery-backed RTC: it boots at 1970 and its app sets the
# clock later. Nebula rejects certificates before their NotBefore, which is
# earlier than now, so wait for the clock to pass the install time.
installed_at="$(date +%s)"
cat >"${work}/S23nebula" <<EOF
#!/bin/sh
# Nebula overlay; installed by scripts/nebula-jetkvm.sh from ~/nixos.
# Init scripts run before the network is up and the KVM app sets the clock,
# so start in the background, wait for both and restart Nebula if it exits.
dir=${REMOTE_DIR}
pidfile=/tmp/nebula-supervisor.pid

running() {
  [ -f "\$pidfile" ] && kill -0 "\$(cat "\$pidfile")" 2>/dev/null
}

case "\$1" in
  start)
    if running; then
      echo "nebula supervisor already running"
      exit 0
    fi
    (
      while [ "\$(date +%s)" -lt ${installed_at} ] || ! ip route | grep -q '^default'; do sleep 5; done
      [ -e /dev/net/tun ] || modprobe tun
      while true; do
        "\$dir/nebula" -config "\$dir/config.yml" >"\$dir/nebula.log" 2>&1
        sleep 10
      done
    ) </dev/null >/dev/null 2>&1 &
    echo \$! >"\$pidfile"
    ;;
  stop)
    if running; then
      kill "\$(cat "\$pidfile")"
    fi
    rm -f "\$pidfile"
    killall nebula 2>/dev/null || true
    ;;
  *)
    echo "Usage: \$0 {start|stop}"
    exit 1
    ;;
esac
EOF

echo "==> Installing on ${address}"
ssh_kvm "mkdir -p ${REMOTE_DIR} /userdata/init.d"
ssh_kvm "cat >${REMOTE_DIR}/nebula.new && chmod 755 ${REMOTE_DIR}/nebula.new" <"${nebula_pkg}/bin/nebula"
ssh_kvm "umask 077 && cat >${REMOTE_DIR}/config.yml.new" <"${work}/config.yml"
ssh_kvm "cat >${INIT_SCRIPT}.new && chmod 755 ${INIT_SCRIPT}.new" <"${work}/S23nebula"
# Earlier versions of the init script could exit non-zero from stop.
ssh_kvm "set -e
if [ -x ${INIT_SCRIPT} ]; then ${INIT_SCRIPT} stop || true; fi
mv ${REMOTE_DIR}/nebula.new ${REMOTE_DIR}/nebula
mv ${REMOTE_DIR}/config.yml.new ${REMOTE_DIR}/config.yml
mv ${INIT_SCRIPT}.new ${INIT_SCRIPT}
sync
${INIT_SCRIPT} start"

echo "==> Waiting for ${peer} to answer on ${ip4}"
for _ in $(seq 30); do
  if ping -c 1 -W 2 "${ip4}" >/dev/null 2>&1; then
    echo "    ${peer} is up: http://${ip4}/ (http://${peer}.${domain}/)"
    exit 0
  fi
  sleep 2
done
echo "error: ${peer} did not answer on ${ip4}; check ${REMOTE_DIR}/nebula.log on the device" >&2
exit 1
