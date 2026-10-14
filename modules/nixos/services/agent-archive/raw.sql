-- The archive proper: every session record from every agent store, verbatim.
-- Never dropped by the schema service; derived tables are rebuilt from it.
CREATE DATABASE IF NOT EXISTS archive;

CREATE TABLE IF NOT EXISTS archive.raw
(
    host LowCardinality(String),
    tool LowCardinality(String),
    -- Files: path relative to $HOME. SQLite: relative path, '#', table.
    source String,
    -- Files: inode, so a file replaced by a rewrite is kept as a separate
    -- generation. SQLite: empty.
    generation String,
    -- JSONL: 1-based line number. Whole files: '0'. SQLite: the row's key;
    -- 'read' on the '<db>#' marker recording when the database was last read.
    key String,
    -- Per-source cursor and row version. JSONL: byte offset of the line's
    -- end. Whole files: mtime in ns. SQLite: the row's update stamp. The
    -- shipper resumes after max(position); the latest version of a key wins.
    position UInt64,
    record String CODEC(ZSTD(6)),
    ingested_at DateTime64(3) DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(position)
-- By ingest month, so a closed month's Parquet backup never changes again.
-- Replacement only merges within a partition: derived queries pick the
-- latest version with argMax rather than relying on FINAL.
PARTITION BY toYYYYMM(ingested_at)
ORDER BY (tool, host, source, generation, key);
