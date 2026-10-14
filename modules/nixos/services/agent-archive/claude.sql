-- Claude Code project journals (.claude and .claude-remote).
--
-- One API response is written as one line per content block, all sharing
-- requestId and message.id; usage counters grow across those lines, so a
-- request takes the largest. Forked sessions copy earlier lines, so requests
-- and tool calls are keyed by their own IDs, not by session. '<synthetic>'
-- messages are written by Claude Code itself without an API call.

CREATE VIEW agents.claude_lines AS
SELECT
    host,
    source,
    record,
    splitByChar('/', source)[1] AS account,
    JSONExtractString(record, 'type') AS type,
    JSONExtractString(record, 'sessionId') AS session_id,
    coalesce(nullIf(JSONExtractString(record, 'requestId'), ''), JSONExtractString(record, 'message', 'id')) AS request_id,
    parseDateTime64BestEffort(JSONExtractString(record, 'timestamp'), 3, 'UTC') AS at,
    JSONExtractArrayRaw(record, 'message', 'content') AS blocks
FROM archive.raw
WHERE tool = 'claude' AND source LIKE '%/projects/%.jsonl'
    AND JSONExtractString(record, 'type') IN ('assistant', 'user');

-- Request duration and time to first token come from telemetry, where it
-- was enabled (agents.claude_request_timing); NULL before that.
CREATE VIEW agents.claude_requests AS
SELECT
    r.tool AS tool,
    r.host AS host,
    r.account AS account,
    r.session_id AS session_id,
    r.request_id AS request_id,
    r.is_subagent AS is_subagent,
    r.model AS model,
    r.ts AS ts,
    t.duration_ms AS duration_ms,
    t.ttft_ms AS ttft_ms,
    r.input_tokens AS input_tokens,
    r.cache_read_tokens AS cache_read_tokens,
    r.cache_write_tokens AS cache_write_tokens,
    r.output_tokens AS output_tokens,
    r.reasoning_tokens AS reasoning_tokens,
    r.stop_reason AS stop_reason,
    r.tool_calls AS tool_calls,
    r.cwd AS cwd
FROM
(
    SELECT
        'claude' AS tool,
        argMin(host, at) AS host,
        argMin(account, at) AS account,
        argMin(session_id, at) AS session_id,
        request_id,
        max(toUInt8(JSONExtractBool(record, 'isSidechain') OR position(source, '/subagents/') > 0)) AS is_subagent,
        argMax(JSONExtractString(record, 'message', 'model'), at) AS model,
        min(at) AS ts,
        max(JSONExtractUInt(record, 'message', 'usage', 'input_tokens')) AS input_tokens,
        max(JSONExtractUInt(record, 'message', 'usage', 'cache_read_input_tokens')) AS cache_read_tokens,
        max(JSONExtractUInt(record, 'message', 'usage', 'cache_creation_input_tokens')) AS cache_write_tokens,
        max(JSONExtractUInt(record, 'message', 'usage', 'output_tokens')) AS output_tokens,
        max(JSONExtract(record, 'message', 'usage', 'output_tokens_details', 'thinking_tokens', 'Nullable(UInt64)')) AS reasoning_tokens,
        argMax(JSONExtractString(record, 'message', 'stop_reason'), JSONExtractString(record, 'message', 'stop_reason') != '') AS stop_reason,
        toUInt32(length(arrayDistinct(arrayFlatten(groupArray(
            arrayMap(b -> JSONExtractString(b, 'id'), arrayFilter(b -> JSONExtractString(b, 'type') = 'tool_use', blocks))
        ))))) AS tool_calls,
        argMin(JSONExtractString(record, 'cwd'), at) AS cwd
    FROM agents.claude_lines
    WHERE type = 'assistant' AND request_id != ''
        AND JSONExtractString(record, 'message', 'model') != '<synthetic>'
    GROUP BY request_id
) AS r
LEFT JOIN
(
    SELECT request_id, argMax(duration_ms, ts) AS duration_ms, argMax(ttft_ms, ts) AS ttft_ms
    FROM agents.claude_request_timing
    WHERE success
    GROUP BY request_id
) AS t ON t.request_id = r.request_id;

-- Duration is the journal interval from the call's line to its result's
-- line: it includes waiting for permission and other queued tools.
CREATE VIEW agents.claude_tool_calls AS
WITH
    calls AS
    (
        SELECT
            JSONExtractString(block, 'id') AS call_id,
            argMin(host, at) AS host,
            argMin(session_id, at) AS session_id,
            argMin(request_id, at) AS request_id,
            min(at) AS ts,
            any(JSONExtractString(block, 'name')) AS name,
            any(JSONExtractRaw(block, 'input')) AS input
        FROM agents.claude_lines
        ARRAY JOIN blocks AS block
        WHERE type = 'assistant' AND JSONExtractString(block, 'type') = 'tool_use'
        GROUP BY call_id
    ),
    results AS
    (
        SELECT
            JSONExtractString(block, 'tool_use_id') AS call_id,
            min(at) AS at,
            max(toUInt8(JSONExtractBool(block, 'is_error'))) AS is_error,
            max(length(JSONExtractRaw(block, 'content'))) AS output_bytes
        FROM agents.claude_lines
        ARRAY JOIN blocks AS block
        WHERE type = 'user' AND JSONExtractString(block, 'type') = 'tool_result'
        GROUP BY call_id
    )
SELECT
    'claude' AS tool,
    calls.host AS host,
    calls.session_id AS session_id,
    calls.request_id AS request_id,
    calls.call_id AS call_id,
    calls.ts AS ts,
    calls.name AS name,
    calls.input AS input,
    if(results.call_id = '', NULL, results.is_error) AS is_error,
    if(results.call_id = '', NULL, results.output_bytes) AS output_bytes,
    if(results.call_id = '', NULL, toFloat64(dateDiff('millisecond', calls.ts, results.at))) AS duration_ms
FROM calls
LEFT JOIN results ON calls.call_id = results.call_id;
