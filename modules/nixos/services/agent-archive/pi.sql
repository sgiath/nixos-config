-- Pi session format v3: oh-my-pi (.omp and its named profiles under
-- .omp/profiles/<name>), the older OmO harness (.omo), plain Pi (.pi) and
-- Prime (.prime). One assistant entry is one complete API response.
--
-- OMP rewrites session files, so the same entries can appear in several
-- generations; requests and tool calls are keyed by their own IDs. OMP also
-- records the measured request duration and time to first token. Auxiliary
-- `model_usage` entries (titles, compaction) are not counted as requests.

CREATE VIEW agents.pi_lines AS
SELECT
    tool,
    host,
    source,
    record,
    JSONExtractString(record, 'type') AS type,
    JSONExtractString(record, 'message', 'role') AS role,
    JSONExtractString(record, 'id') AS entry_id,
    parseDateTime64BestEffort(JSONExtractString(record, 'timestamp'), 3, 'UTC') AS at
FROM archive.raw
WHERE tool IN ('omp', 'omo', 'pi', 'prime') AND source LIKE '%.jsonl';

CREATE VIEW agents.pi_sessions AS
SELECT
    source,
    any(JSONExtractString(record, 'id')) AS session_id,
    toUInt8(any(JSONExtractString(record, 'parentSession') != '')) AS is_subagent,
    any(JSONExtractString(record, 'cwd')) AS cwd
FROM agents.pi_lines
WHERE type = 'session'
GROUP BY source;

CREATE VIEW agents.pi_requests AS
SELECT
    any(l.tool) AS tool,
    any(l.host) AS host,
    -- A named OMP profile is its own account.
    any(coalesce(nullIf(extract(l.source, '^(\\.omp/profiles/[^/]+)/'), ''), splitByChar('/', l.source)[1])) AS account,
    any(s.session_id) AS session_id,
    coalesce(nullIf(JSONExtractString(l.record, 'message', 'responseId'), ''), concat(s.session_id, ':', l.entry_id)) AS request_id,
    any(s.is_subagent) AS is_subagent,
    any(JSONExtractString(l.record, 'message', 'model')) AS model,
    min(fromUnixTimestamp64Milli(JSONExtractInt(l.record, 'message', 'timestamp'), 'UTC')) AS ts,
    any(JSONExtract(l.record, 'message', 'duration', 'Nullable(Float64)')) AS duration_ms,
    any(JSONExtract(l.record, 'message', 'ttft', 'Nullable(Float64)')) AS ttft_ms,
    any(JSONExtractUInt(l.record, 'message', 'usage', 'input')) AS input_tokens,
    any(JSONExtractUInt(l.record, 'message', 'usage', 'cacheRead')) AS cache_read_tokens,
    any(JSONExtractUInt(l.record, 'message', 'usage', 'cacheWrite')) AS cache_write_tokens,
    any(JSONExtractUInt(l.record, 'message', 'usage', 'output')) AS output_tokens,
    any(coalesce(
        JSONExtract(l.record, 'message', 'usage', 'reasoningTokens', 'Nullable(UInt64)'),
        JSONExtract(l.record, 'message', 'usage', 'reasoning', 'Nullable(UInt64)')
    )) AS reasoning_tokens,
    any(JSONExtractString(l.record, 'message', 'stopReason')) AS stop_reason,
    toNullable(toUInt32(any(length(arrayFilter(
        b -> JSONExtractString(b, 'type') = 'toolCall', JSONExtractArrayRaw(l.record, 'message', 'content')
    ))))) AS tool_calls,
    any(s.cwd) AS cwd
FROM agents.pi_lines AS l
LEFT JOIN agents.pi_sessions AS s ON l.source = s.source
WHERE l.type = 'message' AND l.role = 'assistant'
GROUP BY request_id;

-- Duration runs from the persisted assistant entry to the persisted result:
-- parallel calls of one response share their start.
CREATE VIEW agents.pi_tool_calls AS
WITH
    calls AS
    (
        SELECT
            JSONExtractString(block, 'id') AS call_id,
            any(tool) AS tool,
            any(host) AS host,
            any(source) AS source,
            any(JSONExtractString(record, 'message', 'responseId')) AS request_id,
            min(at) AS ts,
            any(JSONExtractString(block, 'name')) AS name,
            any(JSONExtractRaw(block, 'arguments')) AS input
        FROM agents.pi_lines
        ARRAY JOIN JSONExtractArrayRaw(record, 'message', 'content') AS block
        WHERE type = 'message' AND role = 'assistant' AND JSONExtractString(block, 'type') = 'toolCall'
        GROUP BY call_id
    ),
    results AS
    (
        SELECT
            JSONExtractString(record, 'message', 'toolCallId') AS call_id,
            min(at) AS at,
            max(toUInt8(JSONExtractBool(record, 'message', 'isError'))) AS is_error,
            max(length(JSONExtractRaw(record, 'message', 'content'))) AS output_bytes
        FROM agents.pi_lines
        WHERE type = 'message' AND role = 'toolResult'
        GROUP BY call_id
    )
SELECT
    calls.tool AS tool,
    calls.host AS host,
    s.session_id AS session_id,
    calls.request_id AS request_id,
    calls.call_id AS call_id,
    calls.ts AS ts,
    calls.name AS name,
    calls.input AS input,
    if(results.call_id = '', NULL, results.is_error) AS is_error,
    if(results.call_id = '', NULL, results.output_bytes) AS output_bytes,
    if(results.call_id = '', NULL, toFloat64(dateDiff('millisecond', calls.ts, results.at))) AS duration_ms
FROM calls
LEFT JOIN results ON calls.call_id = results.call_id
LEFT JOIN agents.pi_sessions AS s ON calls.source = s.source;
