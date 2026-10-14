-- Codex rollouts (.codex and .codex-remote), one JSONL file per thread.
--
-- Per-response usage (`token_usage_record`) exists only since September 2026.
-- Older rollouts carry cumulative `token_count` snapshots: each new total is
-- one response, `last_token_usage` its usage. Codex input counts include the
-- cached and cache-write parts; here they are split so every tool reports
-- disjoint input categories. The 2025 whole-JSON rollouts carry no usage.
-- Time to first token comes from telemetry (agents.codex_response_timing)
-- where it was enabled.

CREATE VIEW agents.codex_lines AS
SELECT
    host,
    source,
    toUInt64(key) AS line,
    record,
    splitByChar('/', source)[1] AS account,
    JSONExtractString(record, 'type') AS type,
    JSONExtractString(record, 'payload', 'type') AS payload_type,
    parseDateTime64BestEffort(JSONExtractString(record, 'timestamp'), 3, 'UTC') AS at
FROM archive.raw
WHERE tool = 'codex' AND source LIKE '%sessions/%.jsonl';

CREATE VIEW agents.codex_threads AS
SELECT
    source,
    argMin(JSONExtractString(record, 'payload', 'id'), line) AS session_id,
    toUInt8(argMin(
        JSONHas(record, 'payload', 'source', 'subagent') OR JSONExtractString(record, 'payload', 'parent_thread_id') != '',
        line
    )) AS is_subagent,
    argMin(JSONExtractString(record, 'payload', 'cwd'), line) AS cwd
FROM agents.codex_lines
WHERE type = 'session_meta'
GROUP BY source;

CREATE VIEW agents.codex_requests AS
WITH
    turns AS
    (
        SELECT source, line, JSONExtractString(record, 'payload', 'model') AS model
        FROM agents.codex_lines
        WHERE type = 'turn_context'
    ),
    recorded AS
    (
        SELECT
            host,
            account,
            source,
            line,
            at,
            JSONExtractString(record, 'payload', 'response_id') AS request_id,
            JSONExtractRaw(record, 'payload', 'usage') AS usage
        FROM agents.codex_lines
        WHERE type = 'token_usage_record'
    ),
    -- Repeated snapshots of one total collapse to its first appearance.
    cumulative AS
    (
        SELECT
            any(host) AS host,
            any(account) AS account,
            source,
            min(line) AS first_line,
            min(at) AS first_at,
            concat('token_count:', source, ':', toString(total)) AS request_id,
            argMin(JSONExtractRaw(record, 'payload', 'info', 'last_token_usage'), line) AS usage
        FROM agents.codex_lines
        WHERE type = 'event_msg' AND payload_type = 'token_count'
            AND JSONExtractRaw(record, 'payload', 'info') NOT IN ('', 'null')
            AND source NOT IN (SELECT source FROM agents.codex_lines WHERE type = 'token_usage_record')
        GROUP BY source, JSONExtractUInt(record, 'payload', 'info', 'total_token_usage', 'total_tokens') AS total
    ),
    usages AS
    (
        SELECT * FROM recorded
        UNION ALL
        SELECT host, account, source, first_line, first_at, request_id, usage FROM cumulative
    )
SELECT
    'codex' AS tool,
    argMin(u.host, u.at) AS host,
    argMin(u.account, u.at) AS account,
    argMin(t.session_id, u.at) AS session_id,
    u.request_id AS request_id,
    max(t.is_subagent) AS is_subagent,
    argMin(turns.model, u.at) AS model,
    min(u.at) AS ts,
    CAST(NULL AS Nullable(Float64)) AS duration_ms,
    any(timing.ttft_ms) AS ttft_ms,
    max(greatest(toInt64(JSONExtractUInt(u.usage, 'input_tokens'))
        - JSONExtractUInt(u.usage, 'cached_input_tokens')
        - JSONExtractUInt(u.usage, 'cache_write_input_tokens'), 0)) AS input_tokens,
    max(JSONExtractUInt(u.usage, 'cached_input_tokens')) AS cache_read_tokens,
    max(JSONExtractUInt(u.usage, 'cache_write_input_tokens')) AS cache_write_tokens,
    max(JSONExtractUInt(u.usage, 'output_tokens')) AS output_tokens,
    max(JSONExtract(u.usage, 'reasoning_output_tokens', 'Nullable(UInt64)')) AS reasoning_tokens,
    '' AS stop_reason,
    CAST(NULL AS Nullable(UInt32)) AS tool_calls,
    argMin(t.cwd, u.at) AS cwd
FROM usages AS u
ASOF LEFT JOIN turns ON u.source = turns.source AND u.line >= turns.line
LEFT JOIN agents.codex_threads AS t ON u.source = t.source
-- Telemetry has no response id; the same session and token counts identify it.
LEFT JOIN agents.codex_response_timing AS timing
    ON timing.session_id = t.session_id
    AND timing.input_tokens = JSONExtractUInt(u.usage, 'input_tokens')
    AND timing.output_tokens = JSONExtractUInt(u.usage, 'output_tokens')
WHERE u.request_id != ''
GROUP BY u.request_id;

CREATE VIEW agents.codex_tool_calls AS
WITH
    calls AS
    (
        SELECT
            JSONExtractString(record, 'payload', 'call_id') AS call_id,
            argMin(host, at) AS host,
            argMin(source, at) AS source,
            min(at) AS ts,
            any(JSONExtractString(record, 'payload', 'name')) AS name,
            any(if(payload_type = 'function_call', JSONExtractString(record, 'payload', 'arguments'),
                JSONExtractString(record, 'payload', 'input'))) AS input
        FROM agents.codex_lines
        WHERE type = 'response_item' AND payload_type IN ('function_call', 'custom_tool_call')
        GROUP BY call_id
    ),
    results AS
    (
        SELECT
            JSONExtractString(record, 'payload', 'call_id') AS call_id,
            min(at) AS at,
            max(length(JSONExtractRaw(record, 'payload', 'output'))) AS output_bytes
        FROM agents.codex_lines
        WHERE type = 'response_item' AND payload_type IN ('function_call_output', 'custom_tool_call_output')
        GROUP BY call_id
    )
SELECT
    'codex' AS tool,
    calls.host AS host,
    t.session_id AS session_id,
    '' AS request_id,
    calls.call_id AS call_id,
    calls.ts AS ts,
    calls.name AS name,
    calls.input AS input,
    CAST(NULL AS Nullable(UInt8)) AS is_error,
    if(results.call_id = '', NULL, results.output_bytes) AS output_bytes,
    if(results.call_id = '', NULL, toFloat64(dateDiff('millisecond', calls.ts, results.at))) AS duration_ms
FROM calls
LEFT JOIN results ON calls.call_id = results.call_id
LEFT JOIN agents.codex_threads AS t ON calls.source = t.source
WHERE calls.call_id != '';

-- Code-mode rollouts run commands from an `exec` script and record each as a
-- CommandExecution item, with exit code and measured duration. Other
-- rollouts call exec_command/shell_command directly. The few rollouts with
-- both record each command twice, so CommandExecution items win per file.
CREATE VIEW agents.codex_commands AS
WITH
    items AS
    (
        SELECT
            host,
            source,
            JSONExtractString(record, 'payload', 'item', 'id') AS call_id,
            fromUnixTimestamp64Milli(JSONExtractInt(record, 'payload', 'started_at_ms'), 'UTC') AS ts,
            JSONExtractArrayRaw(record, 'payload', 'item', 'command') AS argv,
            JSONExtract(record, 'payload', 'item', 'exit_code', 'Nullable(Int32)') AS exit_code,
            JSONExtractUInt(record, 'payload', 'item', 'duration', 'secs') * 1000
                + JSONExtractUInt(record, 'payload', 'item', 'duration', 'nanos') / 1e6 AS duration_ms
        FROM agents.codex_lines
        WHERE type = 'event_msg' AND payload_type = 'item_completed'
            AND JSONExtractString(record, 'payload', 'item', 'type') = 'CommandExecution'
    ),
    direct AS
    (
        SELECT
            host,
            source,
            JSONExtractString(record, 'payload', 'call_id') AS call_id,
            at AS ts,
            JSONExtractString(record, 'payload', 'arguments') AS arguments
        FROM agents.codex_lines
        WHERE type = 'response_item' AND payload_type = 'function_call'
            AND JSONExtractString(record, 'payload', 'name') IN ('exec_command', 'shell_command')
            AND source NOT IN (SELECT source FROM items)
    )
SELECT
    'codex' AS tool,
    any(i.host) AS host,
    any(t.session_id) AS session_id,
    '' AS request_id,
    i.call_id AS call_id,
    min(i.ts) AS ts,
    any(if(length(i.argv) = 3 AND JSONExtractString(i.argv[2]) IN ('-lc', '-c'),
        JSONExtractString(i.argv[3]),
        arrayStringConcat(arrayMap(a -> JSONExtractString(a), i.argv), ' '))) AS command,
    any(i.exit_code) AS exit_code,
    toNullable(any(i.duration_ms)) AS duration_ms
FROM items AS i
LEFT JOIN agents.codex_threads AS t ON i.source = t.source
GROUP BY i.call_id
UNION ALL
SELECT
    'codex' AS tool,
    any(d.host) AS host,
    any(t.session_id) AS session_id,
    '' AS request_id,
    d.call_id AS call_id,
    min(d.ts) AS ts,
    any(coalesce(nullIf(JSONExtractString(d.arguments, 'cmd'), ''), JSONExtractString(d.arguments, 'command'))) AS command,
    CAST(NULL AS Nullable(Int32)) AS exit_code,
    CAST(NULL AS Nullable(Float64)) AS duration_ms
FROM direct AS d
LEFT JOIN agents.codex_threads AS t ON d.source = t.source
GROUP BY d.call_id;
