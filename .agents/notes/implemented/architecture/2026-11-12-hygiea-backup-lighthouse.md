# Agent Note: Hygiea, an untrusted cloud host for outages and offsite backups

Status: implemented

## Problem

Vesta is the home server, the only Nebula lighthouse and relay, the only Pi-hole and the only place backups could go. When it is down, remote peers cannot find the JetKVMs (including the one that would bring Vesta back), the phone loses DNS, nothing alerts from outside, and Vesta's data has no offsite copy. The owner travels for long periods while Vesta and Ceres stay in Czechia.

## Decision

Hygiea is an Oracle Cloud Always Free `VM.Standard.A1.Flex` (1 OCPU, 6 GB, 200 GB boot volume) in Frankfurt, chosen in the [research note](../../../research/2026-11-12-free-vps-nebula-lighthouse.md); Frankfurt stays close to the fixed end of every relayed connection. `systems/aarch64-linux/hygiea/` runs NixOS without the `sgiath.enable` baseline, installed with nixos-anywhere (`INSTALL.md`).

- **Untrusted peer.** It is a lighthouse and relay through the `lighthouse` field of [the peers table](2026-11-12-nebula-untrusted-peers.md), but no host admits its connections except ICMP. Its secrets live only in `secrets/hygiea.yaml`; it cannot decrypt the shared `nebula.yaml` (`sgiath.nebula.secretsFile`).
- **Second Pi-hole.** `services/pi-hole.nix` no longer needs the server role; its nginx UI does. Hygiea answers DNS on the overlay only and carries the peer and overlay-service records but no vhost records, so public names come consistently from upstream. Hosts list `sgiath.nebula.resolvers` (Vesta, Hygiea) before `1.1.1.1`; the phone config lists both. Trusting Hygiea's DNS answers is a separate, accepted boundary from Nebula admission.
- **Offsite backups.** Vesta pushes restic snapshots to an append-only REST server on Hygiea, which never gets the repository password. Only Ceres holds a credential that can delete (an SFTP key for Hygiea's `restic` user in `secrets/ceres.yaml`); it unlocks, forgets, prunes and checks weekly, and refuses to forget while a snapshot is dated in the future, because `--keep-within` counts from the newest snapshot, whose time the writer picks. Scope: Vesta's irreplaceable state, the agent archive's Parquet copies, Hermes/T3 state and source with unpushed work; not OTel telemetry, Docker dev databases or anything rebuildable. SQLite databases are copied with the online backup API, Continuwuity is stopped for a copy of its RocksDB.
- **Monitoring from outside.** Gatus on Hygiea pings Vesta, the JetKVMs and the home public IP and alerts to a secret ntfy.sh topic, since Vesta's ntfy is down when it matters.
- **Idle reclamation.** Oracle may stop idle Always Free VMs. `hygiea-watchdog` on Vesta starts it through the OCI API with a dedicated user whose permissions cover only the `hygiea` compartment; Oracle has no start-only permission, so the key could also stop or reset Hygiea.

## Alternatives considered

- **Use the `sgiath.enable` baseline on Hygiea.** Brings Home Manager, agent tooling, shared GitHub/CLIProxy secrets and a disabled firewall to a public, untrusted VM.
- **Run T3 or other real load to avoid reclamation.** Would make Hygiea trusted and give it credentials; Oracle's memory metrics also need its guest agent, so load alone is no proven exemption.
- **Restic over plain SFTP, or Borg append-only.** SFTP lets the writer delete history; Borg's append-only still allows logical deletion and needs careful compaction. The REST server rejects deletion outright (verified: 403).
- **A region near the traveller (São Paulo).** Only helps relayed traffic in one region and slows backups.
- **Tunnel monitoring from Vesta (heartbeats).** Cannot alert when Vesta itself is down; ICMP-only admission from lighthouses is the narrow exception instead.

## Consequences

- The public IP is ephemeral: it survives stop/start, not termination. A rebuilt Hygiea needs the new IP in the peers table, the new instance OCID in the watchdog, and redeployment of every host, JetKVM and the phone config (`INSTALL.md`).
- The agent archive grows ~1.5 GB a month and is kept forever; the 140 GB cap (`rest-server --max-size`) will eventually need a retention decision or more storage.
- The backup timer is off until Vesta's NIC stops losing large outbound packets (`scripts/link-check.sh`); the [agent archive offsite proposal](../../proposed/feature/2026-10-14-agent-archive-follow-ups.md) stays open until a full backup has run and a restore into scratch tables matched.
- The Turris cannot reach Hygiea's Pi-hole (it is no Nebula peer), so LAN clients and the JetKVMs still lose DNS when Vesta is down.
- Verified 2026-11-12: Hygiea exposes only SSH, UDP 4242 and ICMP publicly; Ceres reached `kvm-ceres` and Hygiea with Vesta blocked and resolved names in about a second; Vesta's `forget` got HTTP 403; a tiny backup restored on Ceres; a future-dated snapshot stopped the weekly cleanup; stopping Hygiea through OCI was undone by the watchdog within about two minutes, with ntfy messages.
