# Agent Note: Agent archive follow-ups

Status: proposed

## Problem

The [agent session archive](../../implemented/architecture/2026-10-14-agent-session-archive.md)
ships text session records from the main stores and normalizes Claude Code,
Codex, OpenCode, the Pi family, Cursor, Muse and Grok. Some data is still only
on its source host or only raw, and no restore from the offsite copy has been
tried.

## Proposal

- **Offsite restore check.** Vesta's nightly restic backup to Hygiea
  (`systems/x86_64-linux/vesta/offsite-backup.nix`) includes
  `/var/backup/agent-archive`; restore a closed month's Parquet files from it
  into scratch tables and compare them with that month of `archive.raw` and
  `archive.cliproxy`.
- **Binary assets.** Archive OMP blobs (`~/.omp/agent/blobs/<sha256>`,
  referenced as `blob:sha256:` from sessions) and T3 message attachments
  (`~/.t3/userdata/attachments`), content-addressed so each is stored once.
- **T3 provider logs.** `~/.t3/userdata/logs/provider/*.log` rotate; they carry
  Claude SDK TTFT and Codex measured command durations that would sharpen
  timing metrics. Needs rotation-aware shipping and an allowlist that drops
  account/rate-limit RPCs.
- **More normalizers.** T3 (thread titles, runs, provider thread links through
  `nativeThreadRef.nativeId`), Hermes (session/route aggregates only).
- **Hermes reconciliation.** Re-ship changed sessions' messages. Hermes
  messages have no update stamp, so `ship.py` reads them by `id` and ships each
  row as first seen; compaction later flips `active` and `compacted` in place.
  On 2026-11-18, 289 messages that Vesta's `hermes/.hermes/state.db` marks
  inactive were still active in their latest archived copy. Sessions carry
  `transcript_revision`, `runtime_revision` and `last_activity_at`, which could
  select the sessions whose messages to re-read.

## Alternatives considered

- Storing blobs base64 inside `archive.raw`: works without new storage, but
  bloats the table scanned by every derived refresh.

## Acceptance criteria

- A closed month restored from the offsite copy matches that month of
  `archive.raw` and `archive.cliproxy` row for row.
- Each new normalizer reconciles against independent counts from its source
  store, as the first ones did.

## Risks

- Provider logs and attachments can contain credentials pasted into sessions;
  offsite storage must be encrypted.
