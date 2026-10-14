-- Analysis tables, rebuilt every hour from archive.raw through the per-tool
-- views, half an hour after the shippers start. Token columns are disjoint:
-- uncached input, cache reads, cache writes, output (reasoning is part of
-- output). NULL means the tool does not record the value.

CREATE TABLE agents.requests
(
    tool LowCardinality(String),
    host LowCardinality(String),
    account LowCardinality(String),
    session_id String,
    request_id String,
    is_subagent UInt8,
    model LowCardinality(String),
    ts DateTime64(3, 'UTC'),
    duration_ms Nullable(Float64),
    ttft_ms Nullable(Float64),
    input_tokens UInt64,
    cache_read_tokens UInt64,
    cache_write_tokens UInt64,
    output_tokens UInt64,
    reasoning_tokens Nullable(UInt64),
    stop_reason LowCardinality(String),
    tool_calls Nullable(UInt32),
    cwd String
)
ENGINE = MergeTree
ORDER BY (tool, ts);

CREATE MATERIALIZED VIEW agents.requests_refresh
REFRESH EVERY 1 HOUR OFFSET 30 MINUTE TO agents.requests AS
SELECT * FROM agents.claude_requests
UNION ALL SELECT * FROM agents.codex_requests
UNION ALL SELECT * FROM agents.pi_requests
UNION ALL SELECT * FROM agents.opencode_requests
UNION ALL SELECT * FROM agents.cursor_requests
UNION ALL SELECT * FROM agents.muse_requests
UNION ALL SELECT * FROM agents.grok_requests;

-- Model-issued tool calls. request_id is empty where the tool does not link
-- calls to responses (Codex).
CREATE TABLE agents.tool_calls
(
    tool LowCardinality(String),
    host LowCardinality(String),
    session_id String,
    request_id String,
    call_id String,
    ts DateTime64(3, 'UTC'),
    name LowCardinality(String),
    input String,
    is_error Nullable(UInt8),
    output_bytes Nullable(UInt64),
    duration_ms Nullable(Float64)
)
ENGINE = MergeTree
ORDER BY (tool, ts);

CREATE MATERIALIZED VIEW agents.tool_calls_refresh
REFRESH EVERY 1 HOUR OFFSET 30 MINUTE TO agents.tool_calls AS
SELECT * FROM agents.claude_tool_calls
UNION ALL SELECT * FROM agents.codex_tool_calls
UNION ALL SELECT * FROM agents.pi_tool_calls
UNION ALL SELECT * FROM agents.opencode_tool_calls
UNION ALL SELECT * FROM agents.opencode_hook_tool_calls
UNION ALL SELECT * FROM agents.cursor_tool_calls
UNION ALL SELECT * FROM agents.muse_tool_calls
UNION ALL SELECT * FROM agents.grok_tool_calls;

-- Shell commands as executed: one row per command, including each command a
-- Codex code-mode script ran.
CREATE TABLE agents.commands
(
    tool LowCardinality(String),
    host LowCardinality(String),
    session_id String,
    request_id String,
    call_id String,
    ts DateTime64(3, 'UTC'),
    command String,
    exit_code Nullable(Int32),
    duration_ms Nullable(Float64)
)
ENGINE = MergeTree
ORDER BY (tool, ts);

CREATE MATERIALIZED VIEW agents.commands_refresh
REFRESH EVERY 1 HOUR OFFSET 30 MINUTE DEPENDS ON agents.tool_calls_refresh TO agents.commands AS
SELECT
    tool,
    host,
    session_id,
    request_id,
    call_id,
    ts,
    JSONExtractString(input, 'command') AS command,
    CAST(NULL AS Nullable(Int32)) AS exit_code,
    duration_ms
FROM agents.tool_calls
WHERE (tool = 'claude' AND name = 'Bash')
    OR (tool IN ('omp', 'omo', 'pi', 'prime', 'opencode', 'muse') AND name = 'bash')
    OR (tool = 'cursor' AND name = 'run_terminal_cmd')
    OR (tool = 'grok' AND name = 'run_terminal_command')
UNION ALL
SELECT * FROM agents.codex_commands;

CREATE VIEW agents.sessions AS
SELECT
    tool,
    session_id,
    any(host) AS host,
    any(account) AS account,
    max(is_subagent) AS is_subagent,
    topK(1)(model)[1] AS model,
    any(cwd) AS cwd,
    min(ts) AS started,
    max(ts) AS last_request,
    count() AS requests,
    sum(input_tokens) AS input_tokens,
    sum(cache_read_tokens) AS cache_read_tokens,
    sum(cache_write_tokens) AS cache_write_tokens,
    sum(output_tokens) AS output_tokens
FROM agents.requests
GROUP BY tool, session_id;
