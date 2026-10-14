# Agent Note: Agent archive follow-ups

Status: proposed

## Problem

The [agent session archive](../../implemented/architecture/2026-10-14-agent-session-archive.md)
ships text session records from the main stores and normalizes Claude Code,
Codex, OpenCode, the Pi family, Cursor, Muse and Grok. Some data is still only
on its source host or only raw, and every copy of the archive is in the same
house.

## Proposal

- **Offsite backup.** Sync `/var/backup/agent-archive` (self-contained
  Parquet files, one per ingest month, closed months immutable) to an offsite
  target with restic or rclone once one is chosen.
- **Binary assets.** Archive OMP blobs (`~/.omp/agent/blobs/<sha256>`,
  referenced as `blob:sha256:` from sessions) and T3 message attachments
  (`~/.t3/userdata/attachments`), content-addressed so each is stored once.
- **T3 provider logs.** `~/.t3/userdata/logs/provider/*.log` rotate; they carry
  Claude SDK TTFT and Codex measured command durations that would sharpen
  timing metrics. Needs rotation-aware shipping and an allowlist that drops
  account/rate-limit RPCs.
- **More normalizers.** T3 (thread titles, runs, provider thread links through
  `nativeThreadRef.nativeId`), Hermes (session/route aggregates only),
  OpenClaw.
- **Hermes reconciliation.** Re-ship changed sessions' messages, since Hermes
  has no update stamps.

## Alternatives considered

- Storing blobs base64 inside `archive.raw`: works without new storage, but
  bloats the table scanned by every derived refresh.

## Acceptance criteria

- An offsite copy restores into a scratch table identical to `archive.raw`.
- Each new normalizer reconciles against independent counts from its source
  store, as the first ones did.

## Risks

- Provider logs and attachments can contain credentials pasted into sessions;
  offsite storage must be encrypted.
