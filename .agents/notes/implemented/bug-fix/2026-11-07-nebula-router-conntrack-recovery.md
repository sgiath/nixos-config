# Agent Note: Recover Nebula after a router reboot leaves untranslated UDP state

Status: implemented

## Problem

Ceres loses access to Vesta over Nebula after the Turris Omnia router reboots around 14:31 UTC (15:31 Prague time) on 2026-11-07. Public-IP connectivity and direct LAN SSH to Vesta remain available. CLIProxy is healthy on Vesta itself, but unreachable from Ceres over the overlay. T3 logs contain `EAI_AGAIN` lookup failures for `api.github.com`; this establishes DNS failures, not that every reported T3 UI disconnection has the same cause.

The observed router connection is:

```text
UDP 192.168.1.7:51580 -> 193.165.30.198:4242
UNREPLIED; reply tuple 193.165.30.198:4242 -> 192.168.1.7:51580
```

It lacks DNAT to Vesta (`192.168.1.2`). A header-only packet capture shows Ceres's packets arriving without forwarding to Vesta. The live firewall contains the correct LAN NAT-reflection DNAT and SNAT rules. The router's UDP idle timeout is 60 seconds; Nebula retries every few seconds on the same source port, keeping the untranslated connection alive.

The supported failure mechanism is persistent untranslated connection-tracking state. Creation of that state before the NAT rules load during boot is a plausible trigger, but was not captured. This incident does not establish a Nebula implementation defect.

[The shared Nebula configuration](../../../../modules/nixos/common/nebula.nix) gives both lighthouse overlay addresses only the public endpoint, so Ceres depends on hairpin NAT even on Vesta's LAN. Its primary DNS server is Vesta's overlay address, extending the impact beyond private services. No direct-LAN bootstrap fallback is configured.

### Reboot and security findings

- The router boots around 14:31 UTC. Mixed local/UTC timestamps in its startup log require care; Ceres's tunnel-death timestamps and router uptime independently corroborate the interruption.
- The persistent updater changelog and Schnapps snapshots record an automatic TurrisOS 9.1.4 to 9.1.5 update at approximately 00:48 local time, predominantly OpenSSH packages. This is not evidence that the update caused the afternoon reboot.
- `user_notify.reboot` specifies a three-day delay and `03:30`, which does not explain this reboot under normal scheduling. No pending `at` jobs remain after boot, but those jobs live in volatile storage, so their absence cannot establish what was scheduled before reboot.
- MCU firmware uptime is about 28 days while Linux uptime is minutes. This argues against a complete power interruption, but does not identify the reset mechanism.
- Current WAN input policy rejects unsolicited management traffic. Explicit WAN SSH, HTTP and HTTPS management exceptions are disabled. This describes the inspected current policy, not a historical guarantee.
- Successful SSH logins in the initially preserved post-boot log correspond to this investigation from Ceres (`192.168.1.7`). No unauthorized login is established by the available evidence.
- `/var` points to `/tmp`; system logs are volatile, with `log_size=64` and no remote system-log destination configured. No pstore crash record is available. Ordinary watchdog initialization messages do not demonstrate a watchdog-triggered reboot.

**The reboot cause remains unknown. No attack is established, and an attack cannot be excluded from post-boot logs alone.** Software-requested reboot, crash/watchdog reset and physical reset are not distinguished by the surviving evidence.

## Decision

Recover the affected path by deleting only the exact untranslated UDP connection on the router, allowing the next Nebula retry to create a fresh NAT mapping. Do not flush connection tracking globally, reboot the router, or restart T3 or Nebula.

The authorized recovery runs at approximately 14:51 UTC:

```sh
# Inspect the exact tuple first; these addresses/port identify this incident only.
conntrack -L -p udp \
  --orig-src 192.168.1.7 --orig-dst 193.165.30.198 \
  --sport 51580 --dport 4242

# Executed on the router after confirming the untranslated UNREPLIED entry.
conntrack -D -p udp \
  --orig-src 192.168.1.7 --orig-dst 193.165.30.198 \
  --sport 51580 --dport 4242
```

Exactly one entry is deleted. No production configuration or package is changed. This is an operational recovery, not shipped prevention of recurrence. A same-LAN endpoint alternative and off-router logging remain possible reliability/diagnostic improvements, not implemented behavior.

Preserve raw evidence outside Git, because router logs contain network-device identifiers and operational details. The local evidence directory is owner-only:

```text
/home/sgiath/.local/state/nixos-investigations/2026-11-07-nebula-router-ul6aws/
  router-logread.txt
  router-dmesg.txt
  router-findings.txt
  router-recovered.txt
  ceres-recovery-journal.txt
  SHA256SUMS
```

The first three files are copied unchanged from the initial private capture. SHA-256 checksums cover those files and the recovery captures. They are not off-host or independently timestamped forensic evidence. Do not interpret the local archive as proof of system integrity.

## Verification

The original failure checks are red before recovery: overlay ping loses all packets, and HTTPS to CLIProxy forced to `10.42.0.2` times out. Direct LAN SSH to `192.168.1.2` succeeds and CLIProxy returns HTTP 200 from Vesta itself, isolating the failed path.

After deleting the single entry:

- Ceres records a successful Nebula handshake with Vesta at `2026-11-07T14:51:19.293Z`, without restarting either daemon.
- The same UDP tuple acquires DNAT/SNAT state with reply tuple `192.168.1.2:4242 -> 192.168.1.1:51580` and becomes `ASSURED`, with packets in both directions. This live intervention verifies that the stale entry blocks recovery; it does not establish how that entry was first created.
- `ping -n -c 3 -W 2 10.42.0.2`: 3/3 replies.
- `ping -6 -n -c 2 -W 2 fd51:da00:4788::2`: 2/2 replies.
- `ssh -o BatchMode=yes -o ConnectTimeout=4 vesta hostname`: returns `vesta`. SSH to `vesta.nebula.sgiath.dev` also succeeds.
- A check using `vesta.sgiath` fails name resolution; it is not the configured SSH alias. Do not report that name as recovered.
- `dig +time=2 +tries=1 @10.42.0.2 api.github.com A`: `NOERROR` with an A answer; Pi-hole marks this answer stale. This verifies DNS service reachability, not freshness of every upstream answer.
- `getent ahostsv4 api.github.com`: resolves successfully through the system resolver.
- `curl --noproxy '*' --connect-timeout 4 --max-time 8 https://cliproxy.sgiath.dev/`: HTTP 200 using normal hostname resolution.
- `systemctl --user is-active t3code.service`: `active`. Interactive T3 reconnection and long-term connection stability are not verified by this check.

No router reboot reproduction, daemon change, or prevention test is performed. Determining the reboot cause requires independent pre-reboot evidence, such as external monitoring/logs or confirmation of a physical/admin action; none is available in this investigation.
