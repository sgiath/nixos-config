# Agent Note: Agent session archive in ClickHouse

Status: implemented

## Problem

Agent sessions live in a dozen tool-specific stores on several hosts (Claude
Code, Codex, OpenCode, oh-my-pi with its named profiles, OmO, Pi, Prime, T3
Code, Cursor, Grok, Muse, Hermes, OpenClaw). Tools prune them (Claude Code
deleted transcripts after 30 days until `cleanupPeriodDays` was set), rewrite
them, or abandon them when the user moves to another tool. There was no durable copy and no way to analyse usage
across tools.

## Decision

`services.agent-archive` runs ClickHouse on Vesta (`/data/clickhouse`,
`clickhouse.sgiath.dev` on Nebula only). An hourly Home Manager timer on every
host with agents (`modules/home/agents/archive.nix`) ships records to it.

- **Raw is the archive.** `archive.raw` stores every record verbatim: JSONL
  lines, whole files (2025 Codex rollouts, OMP tool-output artifacts) and
  SQLite rows as JSON. It is never dropped by the schema service.
- **Derived data is disposable.** The `agents` database (`requests`,
  `tool_calls`, `commands`, `sessions`) is rebuilt from raw by hourly
  refreshable materialized views over per-tool parsing views, and dropped and
  recreated whenever the SQL changes. A parser fix never needs the original
  files.
- **Cursors live in ClickHouse.** The shipper asks for `max(position)` per
  `(source, generation)` and sends only what follows, so it keeps no local
  state and an offline host catches up on its next run.
- **A file generation is its inode.** OMP replaces session files on rewrite;
  the new inode ships in full next to the old generation instead of
  corrupting byte offsets. Derived views key requests and tool calls by native
  IDs, so copies count once.
- **SQLite read markers.** After reading a database the shipper stores a
  `<db>#` marker with the read time; an unchanged database (by main/WAL mtime)
  is skipped, so OpenCode's unindexed 13 GB store is not rescanned hourly.
- **Backups are portable files.** A daily job writes one Parquet file per
  ingest month of `archive.raw` to `/var/backup/agent-archive` (Vesta's other
  disk), rewriting only changed months.
- **Nebula is the auth.** The `default` user is read-only for analysis; the
  `archive` user writes.

Source discovery, field paths and dedup rules came from a read-only survey of
every store on Ceres and Vesta; the derived counts were reconciled against it
(e.g. Claude request IDs, Codex response IDs, OMP request fixtures, Codex
cumulative totals per rollout).

## Alternatives considered

- **OpenTelemetry export from Claude Code/Codex.** Gives exact request
  latency, but only from now on and only for two tools; history exists only
  in the session stores. Can be added later as another source.
- **Syncing session directories to Vesta.** Simple durability, but no
  analysis, and syncing SQLite files mid-write is unsafe.
- **Normalizing in the shipper.** Testable in Python, but every parser change
  would need the original files again; verbatim raw plus SQL views keeps
  re-derivation server-side.
- **Incremental materialized views.** Cheaper per hour, but duplicates and
  updates across ingest partitions make them wrong without careful dedup;
  a full refresh takes seconds at the current size.

## Consequences

- Durability depends on hosts shipping: a file created and deleted between
  two hourly runs is never archived.
- Rows of SQLite tables without an update stamp (Hermes) are captured as first
  seen; later in-place edits are not.
- Token columns in `agents.requests` are disjoint categories; Codex inclusive
  input is split accordingly. Codex rollouts before September 2026 derive
  per-response usage from cumulative `token_count` snapshots.
- Request duration and TTFT exist only where the tool measures them (OMP).
- OpenCode's database was replaced in June 2026; its 646 earlier sessions
  (Feb–Jun) are recovered from oh-my-opencode's hook copy into `tool_calls`,
  `commands` and `agents.opencode_recovered_sessions`, without requests or
  usage, which that copy never recorded.
- The static Hermes migration store on Vesta is root-only: archive it with a
  one-time root run of `agent-archive-ship`.
- Remaining sources, binary assets and an offsite backup are tracked in
  [agent archive follow-ups](../../proposed/feature/2026-10-14-agent-archive-follow-ups.md).
