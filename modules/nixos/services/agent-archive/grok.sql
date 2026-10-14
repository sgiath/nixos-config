-- Grok Build sessions (~/.grok/sessions/<cwd>/<session>/). chat_history
-- holds one `assistant` row per model response, with model and tool calls
-- but no timestamp; events.jsonl has one `first_token` per response, so the
-- n-th of each is paired within a session. Grok records usage only as a few
-- turn snapshots (updates.jsonl `turn_completed`), so requests carry no
-- tokens. Tool calls take measured duration and outcome from events.jsonl.

CREATE VIEW agents.grok_lines AS
SELECT
    host,
    extract(source, '/([0-9a-f-]{36})/[^/]+$') AS session_id,
    extract(source, '/([a-z_]+)\\.jsonl$') AS file,
    toUInt64(key) AS line,
    record
FROM archive.raw
WHERE tool = 'grok' AND source LIKE '%.jsonl';

CREATE VIEW agents.grok_requests AS
WITH
    responses AS
    (
        SELECT host, session_id, line, record,
            row_number() OVER (PARTITION BY session_id ORDER BY line) AS nth
        FROM agents.grok_lines
        WHERE file = 'chat_history' AND JSONExtractString(record, 'type') = 'assistant'
    ),
    first_tokens AS
    (
        SELECT session_id, parseDateTime64BestEffort(JSONExtractString(record, 'ts'), 3, 'UTC') AS ts,
            row_number() OVER (PARTITION BY session_id ORDER BY line) AS nth
        FROM agents.grok_lines
        WHERE file = 'events' AND JSONExtractString(record, 'type') = 'first_token'
    )
SELECT
    'grok' AS tool,
    r.host AS host,
    '.grok' AS account,
    r.session_id AS session_id,
    concat(r.session_id, ':', toString(r.line)) AS request_id,
    toUInt8(0) AS is_subagent,
    JSONExtractString(r.record, 'model_id') AS model,
    f.ts AS ts,
    CAST(NULL AS Nullable(Float64)) AS duration_ms,
    CAST(NULL AS Nullable(Float64)) AS ttft_ms,
    toUInt64(0) AS input_tokens,
    toUInt64(0) AS cache_read_tokens,
    toUInt64(0) AS cache_write_tokens,
    toUInt64(0) AS output_tokens,
    CAST(NULL AS Nullable(UInt64)) AS reasoning_tokens,
    '' AS stop_reason,
    toNullable(toUInt32(length(JSONExtractArrayRaw(r.record, 'tool_calls')))) AS tool_calls,
    '' AS cwd
FROM responses AS r
INNER JOIN first_tokens AS f ON f.session_id = r.session_id AND f.nth = r.nth;

CREATE VIEW agents.grok_tool_calls AS
WITH
    calls AS
    (
        SELECT
            host,
            session_id,
            concat(session_id, ':', toString(line)) AS request_id,
            JSONExtractString(call, 'id') AS call_id,
            JSONExtractString(call, 'name') AS name,
            JSONExtractString(call, 'arguments') AS input
        FROM agents.grok_lines
        ARRAY JOIN JSONExtractArrayRaw(record, 'tool_calls') AS call
        WHERE file = 'chat_history' AND JSONExtractString(record, 'type') = 'assistant'
    ),
    events AS
    (
        SELECT
            JSONExtractString(record, 'tool_call_id') AS call_id,
            minIf(parseDateTime64BestEffort(JSONExtractString(record, 'ts'), 3, 'UTC'),
                JSONExtractString(record, 'type') = 'tool_started') AS started,
            anyIf(JSONExtractString(record, 'outcome'), JSONExtractString(record, 'type') = 'tool_completed') AS outcome,
            anyIf(JSONExtract(record, 'duration_ms', 'Nullable(Float64)'), JSONExtractString(record, 'type') = 'tool_completed') AS duration_ms
        FROM agents.grok_lines
        WHERE file = 'events' AND JSONExtractString(record, 'type') IN ('tool_started', 'tool_completed')
        GROUP BY call_id
    ),
    results AS
    (
        SELECT JSONExtractString(record, 'tool_call_id') AS call_id, max(length(JSONExtractString(record, 'content'))) AS output_bytes
        FROM agents.grok_lines
        WHERE file = 'chat_history' AND JSONExtractString(record, 'type') = 'tool_result'
        GROUP BY call_id
    )
SELECT
    'grok' AS tool,
    calls.host AS host,
    calls.session_id AS session_id,
    calls.request_id AS request_id,
    calls.call_id AS call_id,
    events.started AS ts,
    calls.name AS name,
    calls.input AS input,
    if(events.outcome = '', NULL, toUInt8(events.outcome != 'success')) AS is_error,
    if(results.call_id = '', NULL, toUInt64(results.output_bytes)) AS output_bytes,
    events.duration_ms AS duration_ms
FROM calls
INNER JOIN events ON events.call_id = calls.call_id
LEFT JOIN results ON results.call_id = calls.call_id;
