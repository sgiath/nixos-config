-- Muse Code session logs (~/.local/share/muse/sessions, one stream per
-- session or subagent). Each `model_completed` event is one model response
-- with measured duration; its input count includes the cached part. Tool
-- calls are committed with their arguments and resolved by a later result
-- batch. A few records are bundled inside retained frames and not unpacked;
-- none of them is a model completion or tool call in the surveyed logs.

CREATE VIEW agents.muse_lines AS
SELECT
    host,
    source,
    record,
    JSONExtractString(record, 'id') AS id,
    JSONExtractString(record, 'stream', 'id') AS session_id,
    toUInt8(position(source, '/subagent/') > 0) AS is_subagent,
    fromUnixTimestamp64Micro(JSONExtractInt(record, 'recorded_at'), 'UTC') AS at,
    JSONExtractString(record, 'payload', 'event', 'kind') AS kind,
    JSONExtractRaw(record, 'payload', 'event') AS event
FROM archive.raw
WHERE tool = 'muse' AND source LIKE '%.jsonl';

CREATE VIEW agents.muse_requests AS
SELECT
    'muse' AS tool,
    any(host) AS host,
    '.local/share/muse' AS account,
    any(session_id) AS session_id,
    id AS request_id,
    any(is_subagent) AS is_subagent,
    any(JSONExtractString(event, 'model')) AS model,
    min(at) AS ts,
    any(JSONExtract(event, 'duration_ms', 'Nullable(Float64)')) AS duration_ms,
    CAST(NULL AS Nullable(Float64)) AS ttft_ms,
    any(toUInt64(greatest(toInt64(JSONExtractUInt(event, 'usage', 'input_tokens'))
        - JSONExtractUInt(event, 'usage', 'cache_read_tokens')
        - JSONExtractUInt(event, 'usage', 'cache_write_tokens'), 0))) AS input_tokens,
    any(JSONExtractUInt(event, 'usage', 'cache_read_tokens')) AS cache_read_tokens,
    any(JSONExtractUInt(event, 'usage', 'cache_write_tokens')) AS cache_write_tokens,
    any(JSONExtractUInt(event, 'usage', 'output_tokens')) AS output_tokens,
    any(JSONExtract(event, 'usage', 'reasoning_tokens', 'Nullable(UInt64)')) AS reasoning_tokens,
    any(JSONExtractString(event, 'finish_reason')) AS stop_reason,
    CAST(NULL AS Nullable(UInt32)) AS tool_calls,
    '' AS cwd
FROM agents.muse_lines
WHERE kind = 'model_completed'
GROUP BY id;

CREATE VIEW agents.muse_tool_calls AS
WITH
    calls AS
    (
        SELECT
            JSONExtractString(call, 'call_id') AS call_id,
            any(host) AS host,
            any(session_id) AS session_id,
            any(JSONExtractString(event, 'response_id')) AS request_id,
            min(at) AS ts,
            any(JSONExtractString(call, 'name')) AS name,
            any(JSONExtractString(call, 'args')) AS input
        FROM agents.muse_lines
        ARRAY JOIN JSONExtractArrayRaw(event, 'tool_calls') AS call
        WHERE kind = 'assistant_tool_calls_committed'
        GROUP BY call_id
    ),
    results AS
    (
        SELECT
            JSONExtractString(result, 'tool_call_id') AS call_id,
            min(at) AS at,
            max(length(JSONExtractString(result, 'text'))) AS output_bytes
        FROM agents.muse_lines
        ARRAY JOIN JSONExtractArrayRaw(event, 'results') AS result
        WHERE kind = 'tool_result_batch_committed'
        GROUP BY call_id
    )
SELECT
    'muse' AS tool,
    calls.host AS host,
    calls.session_id AS session_id,
    calls.request_id AS request_id,
    calls.call_id AS call_id,
    calls.ts AS ts,
    calls.name AS name,
    calls.input AS input,
    CAST(NULL AS Nullable(UInt8)) AS is_error,
    if(results.call_id = '', NULL, toUInt64(results.output_bytes)) AS output_bytes,
    if(results.call_id = '', NULL, toFloat64(dateDiff('millisecond', calls.ts, results.at))) AS duration_ms
FROM calls
LEFT JOIN results ON calls.call_id = results.call_id
WHERE calls.call_id != '';
