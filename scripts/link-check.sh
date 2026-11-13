#!/usr/bin/env bash
# Check Vesta's LAN link for the large-packet loss seen on 2026-11-12
# (enp1s0, Aquantia 10 GbE: ~16% of 1400-byte pings lost to the router, TCP
# uploads at ~1 MB/s). Run on Ceres: it shares the router, had no loss and
# serves as the control for every measurement.
#
# Usage: scripts/link-check.sh [pings-per-path]   (default 500, ~10 s each)
#
# Lost large pings from Vesta fail the check. TCP speed to Cloudflare's
# speed-test endpoint is printed for both machines for comparison; on
# 2026-11-12 Vesta uploaded at ~1 Mbit/s against Ceres's ~200, while its
# downloads were normal. Vesta and Ceres cannot reach each other directly on
# the LAN (ARP fails both ways), so Ceres serves only as a control.
set -euo pipefail

VESTA=vesta.nebula.sgiath.dev
ROUTER=192.168.1.1
NAS=192.168.1.4
HYGIEA=10.42.0.3
SIZE=1400
MAX_LOSS=0.2
# A broken link uploads at ~0.1 MB/s, so keep the upload small enough to
# finish within the timeout instead of reporting nothing.
UP_BYTES=10000000
DOWN_BYTES=50000000
count="${1:-500}"

host="$(uname -n)"
if [[ "$host" != ceres ]]; then
  echo "error: run this on Ceres" >&2
  exit 1
fi

# Command prefix that runs the rest locally or on Vesta.
declare -A on=([vesta]="ssh -o BatchMode=yes $VESTA" [ceres]="")

failed=0
check() {
  local label="$1" where="$2" target="$3" out loss
  out="$(${on[$where]} ping -q -c "$count" -i 0.02 -W 2 -s "$SIZE" "$target" || true)"
  loss="$(grep -oE '[0-9.]+% packet loss' <<<"$out" | cut -d% -f1 || true)"
  loss="${loss:-100}"
  if [[ "$where" == vesta ]] && awk -v v="$loss" -v max="$MAX_LOSS" 'BEGIN { exit !(v > max) }'; then
    failed=1
    printf '%-30s %8s  FAIL\n' "$label" "$loss"
  else
    printf '%-30s %8s\n' "$label" "$loss"
  fi
}

printf '%-30s %8s\n' "${SIZE}-byte pings x ${count}" "loss %"
check "Vesta -> router" vesta "$ROUTER"
check "Vesta -> NAS" vesta "$NAS"
check "Vesta -> Hygiea (Nebula)" vesta "$HYGIEA"
check "Ceres -> router (control)" ceres "$ROUTER"
check "Ceres -> Hygiea (control)" ceres "$HYGIEA"

# Mbit/s of an upload or download through curl, which both hosts have. The
# command is one string: ssh joins its arguments, so a nested `sh -c` would
# lose its quoting on Vesta.
speed() {
  local where="$1" direction="$2" command bps
  if [[ "$direction" == up ]]; then
    command="head -c $UP_BYTES /dev/zero | curl -sS --max-time 150 -o /dev/null -w '%{speed_upload}' --data-binary @- https://speed.cloudflare.com/__up"
  else
    command="curl -sS --max-time 120 -o /dev/null -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=$DOWN_BYTES'"
  fi
  if [[ "$where" == vesta ]]; then
    bps="$(ssh -o BatchMode=yes "$VESTA" "$command" || true)"
  else
    bps="$(sh -c "$command" || true)"
  fi
  awk -v b="${bps:-0}" 'BEGIN { printf "%.1f", b * 8 / 1e6 }'
}

echo
printf '%-30s %8s %8s\n' "TCP to Cloudflare" "up" "down"
for where in vesta ceres; do
  up="$(speed "$where" up)"
  down="$(speed "$where" down)"
  printf '%-30s %8s %8s  Mbit/s\n' "$where" "$up" "$down"
done

echo
if ((failed)); then
  echo "LINK BROKEN: Vesta still loses large packets (limit ${MAX_LOSS}%)."
  exit 1
fi
echo "LINK OK: Vesta loses no more than ${MAX_LOSS}% of large packets."
