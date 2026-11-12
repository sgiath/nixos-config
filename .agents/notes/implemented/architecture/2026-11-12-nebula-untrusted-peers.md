# Agent Note: Untrusted Nebula peers and a lighthouse table

Status: implemented

## Problem

Every Nebula peer was admitted inbound on every host, and services bound to the overlay have no login of their own. Two JetKVMs (one controlling Vesta, one Ceres) need overlay addresses so they stay reachable away from home, but they run a BusyBox firmware with a cloud connection and should not reach any host service. Vesta was also the only lighthouse and relay, set by hand in its host config, so remote access to the KVMs failed exactly when Vesta was down; a second lighthouse ([research](../../../research/2026-11-12-free-vps-nebula-lighthouse.md)) needs a place in the shared config.

## Decision

`sgiath.nebula.peers` entries carry `trusted` (default `false`) and `lighthouse` (numeric public `ip:port` or `null`) in `modules/nixos/common/nebula.nix`.

- Inbound rules on NixOS hosts list only trusted peers by certificate name. Untrusted peers stay reachable because Nebula's firewall is stateful: replies to connections a host opens pass. Lighthouse and relay control traffic is not subject to the inner firewall, so an untrusted lighthouse still works.
- A peer with a `lighthouse` endpoint is lighthouse and relay. Every other peer lists all of them as lighthouses and relays, with `static_host_map` entries to their endpoints. A peer advertises its own relay list to the lighthouses and initiators use the target's list, so every peer must list every relay. Lighthouses list none (Nebula does not relay through a relay).
- JetKVMs are `kvm-<machine>` at `.21`+ with group `kvm`, installed by `scripts/nebula-jetkvm.sh` with a static armv7 build of the hosts' Nebula (`packages/nebula-jetkvm`). Their config admits only trusted peers, starts from `/userdata/init.d` and waits for a default route and a clock past the install time: the device has no RTC and Nebula rejects certificates before their NotBefore.
- `scripts/nebula-mobile.sh` renders lighthouses, relays and inbound rules from the same table, with numeric endpoints; it no longer uses the `nebula.sgiath.dev` name.

## Alternatives considered

- **Keep all peers trusted.** Gives the KVM firmware every overlay service on every host.
- **Groups instead of names in inbound rules.** Equivalent for now, but trust would then live in certificates signed long ago instead of in the reviewed table.
- **Tailscale on the JetKVMs** (JetKVM's documented path). Adds a second overlay and a third-party coordination service.
- **Upstream `nebula-linux-arm-7` release binary.** Needs a pinned hash per version; the cross-build keeps the KVMs on the hosts' version. Nix's cross Go links externally against glibc even with cgo off, so the package forces `-linkmode=internal`.

## Consequences

- A host that should accept connections from a new peer must mark it `trusted`.
- KVM video over the overlay (WebRTC host candidates on `nebula1`) is untested from a remote network; from Ceres the browser picks the LAN candidate.
- Reinstalling a KVM after a factory reset needs Developer Mode and a rerun of the script; OTA updates keep `/userdata`.
- Verified 2026-11-12 on the Ceres JetKVM: overlay ping and HTTP from Ceres and Vesta, device-originated pings to Ceres and Vesta dropped, reboot recovery in about 20 s, Nebula held back while the clock read 1970. Rendered settings for Ceres, Pallas and Juno1 equal the previous ones; Vesta only lost a `static_host_map` entry for itself.
