# Agent Note: overlay listeners also answer on physical interfaces

Status: proposed

## Problem

Found in the security review of the direct T3 Code connections on 2026-11-15. Services that bind a host's Nebula
address, such as the T3 Code user service (`modules/home/agents/t3code.nix`, `--host` = the peer's `ip4`), are
assumed to be reachable only through Nebula, where the certificate-name firewall in `modules/nixos/common/nebula.nix`
admits trusted peers only. Linux uses the weak host model, so it also accepts a packet for `10.42.0.x` that arrives on
the LAN interface. The host firewall is disabled on Vesta and Ceres (`networking.firewall.enable = false`, nftables
off), so nothing drops it.

A machine on the same LAN that routes `10.42.0.2` via Vesta's LAN address reaches T3 on port 3773 without a Nebula
certificate. T3 still requires its own credentials, so this exposes the unauthenticated endpoints (descriptor, OAuth
metadata, pairing) rather than the API. Ceres has served T3 this way for some time; Vesta started to when its server
moved from loopback behind nginx to its Nebula address.

## Proposal

Drop inbound packets addressed to the Nebula CIDRs (`sgiath.nebula.cidr4`/`cidr6`) unless they arrive on the Nebula
interface or loopback, on every host that runs Nebula. One rule covers all overlay listeners instead of one rule per
port. It needs a packet filter on hosts that run without one, so choose between enabling the NixOS firewall with
permissive defaults and a standalone nftables table that coexists with Docker/Podman rules.

## Acceptance criteria

- From a LAN machine with a static route to a host's overlay address via its LAN address, TCP to an overlay listener
  (e.g. `10.42.0.2:3773`) fails; the same connection over Nebula succeeds.
- Nebula itself (UDP 4242/443 on physical addresses), container networking and LAN services keep working.

## Risks

Enabling a packet filter on hosts that run without one can break container networking or LAN services that rely on
the open default.
